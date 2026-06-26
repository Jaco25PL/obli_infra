-- =============================================================
-- SPACE INVADERS SIMPLIFICADO EN ADA
--
-- Cada NAVE es una TASK (como Alice/Bob en clase).
-- Cada BALA es una TASK.
-- La COLISION bala-nave es una CITA (rendezvous):
--   la bala llama a Nave.Impactar, la nave acepta con accept.
--
-- Controles: A = izquierda, D = derecha, W = disparar, Q = salir
-- Compilar:  gnatmake space_invaders.adb
-- =============================================================

with Ada.Text_IO;  use Ada.Text_IO;

procedure Space_Invaders is

   -- =========================================================
   -- CONSTANTES DEL JUEGO
   -- =========================================================
   ANCHO          : constant Integer := 70;  -- ancho del area de juego
   ALTO           : constant Integer := 20;  -- alto del area de juego
   NAVE_ANCHO     : constant Integer := 4;   -- cada nave tiene 4 caracteres: <##>
   NAVES_POR_FILA : constant Integer := 5;   -- 5 naves por fila
   FILAS_NAVES    : constant Integer := 2;   -- 2 filas de naves
   TOTAL_NAVES    : constant Integer := NAVES_POR_FILA * FILAS_NAVES;  -- 10 naves
   MAX_BALAS      : constant Integer := 3;   -- maximo 3 balas simultaneas

   -- =========================================================
   -- TIPOS
   -- =========================================================

   -- Estado de una nave: viva o destruida
   type Estado_Nave_T is (Viva, Destruida);

   -- Informacion de posicion de una nave (compartido entre tasks)
   type Info_Nave is record
      Fila    : Integer        := 0;
      Columna : Integer        := 0;
      Estado  : Estado_Nave_T  := Destruida;
   end record;

   -- Informacion de posicion de una bala (compartido entre tasks)
   type Info_Bala is record
      Fila    : Integer := 0;
      Columna : Integer := 0;
      Activa  : Boolean := False;
   end record;

   -- =========================================================
   -- ESTADO COMPARTIDO (variables globales)
   --
   -- Las tasks de naves y balas escriben aca su posicion.
   -- El loop principal del main lee estas posiciones para
   -- dibujar la pantalla. Es como tener una "pizarra" donde
   -- cada task anota donde esta.
   -- =========================================================
   Nav : array (1 .. TOTAL_NAVES) of Info_Nave;
   Bal : array (1 .. MAX_BALAS) of Info_Bala;

   Canon_Col    : Integer := ANCHO / 2;     -- posicion horizontal del cannon
   Direccion    : Integer := 1;             -- 1 = derecha, -1 = izquierda
   Naves_Vivas  : Integer := TOTAL_NAVES;  -- contador de naves que quedan
   Juego_Activo : Boolean := True;          -- flag para terminar el juego

   -- =========================================================
   -- DECLARACION DE TASK TYPES
   --
   -- task type define un "molde" de tarea que se puede
   -- instanciar varias veces (como task type Semaforo del
   -- material de clase, que despues se instancia A, B, C).
   -- =========================================================

   -- Cada nave es una task. Tiene dos entries:
   --   Iniciar:  para recibir su ID y posicion inicial
   --   Impactar: para la cita (rendezvous) con una bala
   task type Tarea_Nave is
      entry Iniciar (Mi_Id : in Integer; F : in Integer; C : in Integer);
      entry Impactar;
   end Tarea_Nave;

   -- Cada bala es una task. Tiene dos entries:
   --   Iniciar_Bala: para recibir su ID
   --   Disparar:     para que el main le diga "sali disparada desde esta columna"
   task type Tarea_Bala is
      entry Iniciar_Bala (Mi_Id : in Integer);
      entry Disparar (Col_Inicio : in Integer);
   end Tarea_Bala;

   -- Instancias: arrays de tasks (como "R: array 1..8 of semaforo" de clase)
   Naves : array (1 .. TOTAL_NAVES) of Tarea_Nave;
   Balas : array (1 .. MAX_BALAS) of Tarea_Bala;

   -- =========================================================
   -- CUERPO DE TAREA_NAVE
   --
   -- Analogia con clase:
   --   La nave es como Alice o Bob.
   --   Impactar es como paseo_perro (un entry/cita).
   --   El select con delay es como el ejemplo del reactor
   --   que espera una cita o hace algo tras un timeout.
   -- =========================================================
   task body Tarea_Nave is
      Id   : Integer;
      Fila : Integer;
      Col  : Integer;
   begin
      -- Recibir ID y posicion inicial via cita de inicializacion.
      -- accept espera a que el main llame a Iniciar.
      accept Iniciar (Mi_Id : in Integer; F : in Integer; C : in Integer) do
         Id   := Mi_Id;
         Fila := F;
         Col  := C;
      end Iniciar;

      -- Guardar posicion en el estado compartido
      Nav (Id).Fila    := Fila;
      Nav (Id).Columna := Col;
      Nav (Id).Estado  := Viva;

      -- Loop principal: moverse o recibir impacto
      while Nav (Id).Estado = Viva and then Juego_Activo loop

         -- SELECT: acepta una cita entre varias opciones.
         -- Si una bala llama a Impactar, se toma esa rama.
         -- Si pasa el delay sin que nadie llame, se toma la
         -- rama del delay y la nave se mueve.
         select
            -- Rama 1: aceptar la cita Impactar (colision)
            -- Cuando una bala llama Naves(I).Impactar, la nave
            -- acepta aca. Esto es el RENDEZVOUS de la colision.
            accept Impactar;
            Nav (Id).Estado := Destruida;
            Naves_Vivas := Naves_Vivas - 1;

         or
            -- Rama 2: timeout, mover la nave
            -- delay 0.4 = si nadie llama en 0.4 segundos, mover.
            -- Es la "rama temporal" del select, como delay 0.025
            -- del ejemplo del reactor en el material.
            delay 0.4;
            Col := Col + Direccion;
            Nav (Id).Columna := Col;
         end select;

      end loop;
   end Tarea_Nave;

   -- =========================================================
   -- CUERPO DE TAREA_BALA
   --
   -- Analogia con clase:
   --   La bala es una task que "viaja" hacia arriba.
   --   La colision con una nave es una CITA: la bala
   --   llama a Naves(I).Impactar (entry call), y la nave
   --   acepta con accept Impactar (rendezvous).
   --   En las iteraciones donde la bala no choca, no hay
   --   citas (esto lo dice la letra del obligatorio).
   -- =========================================================
   task body Tarea_Bala is
      Id    : Integer;
      Fila  : Integer;
      Col   : Integer;
      Golpe : Boolean;
   begin
      -- Recibir nuestro ID
      accept Iniciar_Bala (Mi_Id : in Integer) do
         Id := Mi_Id;
      end Iniciar_Bala;

      -- Loop externo: esperar a ser disparada, subir, repetir
      loop
         -- Esperar a que el jugador dispare.
         -- "or terminate" hace que la task termine automaticamente
         -- cuando el programa va a finalizar y no hay mas trabajo.
         select
            accept Disparar (Col_Inicio : in Integer) do
               Col := Col_Inicio;
            end Disparar;
         or
            terminate;
         end select;

         -- Arrancar justo arriba del cannon
         Fila := ALTO - 1;
         Bal (Id).Fila    := Fila;
         Bal (Id).Columna := Col;
         Bal (Id).Activa  := True;
         Golpe := False;

         -- Subir paso a paso hasta chocar o salir de pantalla.
         -- "and then" es AND con corto-circuito: si la primera
         -- condicion es falsa, no evalua las demas.
         while Fila >= 1 and then (not Golpe) and then Juego_Activo loop

            -- Comprobar colision con cada nave viva
            for I in 1 .. TOTAL_NAVES loop
               -- Solo revisar naves que esten vivas
               if Nav (I).Estado = Viva
                  and then Fila = Nav (I).Fila
                  and then Col >= Nav (I).Columna
                  and then Col < Nav (I).Columna + NAVE_ANCHO
               then
                  -- LA CITA (rendezvous) de la colision:
                  -- La bala (caller) llama a Naves(I).Impactar.
                  -- La nave (called) acepta con accept Impactar.
                  -- Ambas tasks se sincronizan en este punto.
                  --
                  -- Usamos select/or delay por si la nave ya murio
                  -- entre el chequeo y la llamada. Sin el delay,
                  -- la bala quedaria bloqueada para siempre.
                  --
                  -- El begin/exception atrapa Tasking_Error que
                  -- ocurre si la task de la nave ya termino.
                  begin
                     select
                        Naves (I).Impactar;
                        Golpe := True;
                     or
                        delay 0.01;
                     end select;
                  exception
                     when Tasking_Error => null;
                  end;
                  exit;  -- salir del for, ya encontramos la nave
               end if;
            end loop;

            -- Si no hubo golpe, subir un paso
            if not Golpe then
               Fila := Fila - 1;
               Bal (Id).Fila := Fila;
               delay 0.07;  -- velocidad de la bala
            end if;
         end loop;

         -- La bala se desactiva (llego arriba o impacto una nave)
         Bal (Id).Activa := False;
      end loop;
   end Tarea_Bala;

   -- =========================================================
   -- PROCEDIMIENTO PARA DIBUJAR LA PANTALLA
   --
   -- OJO: las siguientes cosas NO se vieron en clase,
   -- hay que estudiarlas aparte:
   --   - Character'Val(27): obtiene el caracter con codigo
   --     ASCII 27, que es ESC (escape). Se usa para enviar
   --     comandos a la terminal.
   --   - ESC[2J: codigo ANSI que limpia toda la pantalla.
   --   - ESC[H:  codigo ANSI que mueve el cursor al inicio
   --     (fila 1, columna 1).
   --   - Esto es estandar en terminales Linux/Mac/Windows
   --     modernas, no es algo de ADA en si.
   -- =========================================================
   procedure Dibujar is
      -- Buffer de pantalla: una matriz de caracteres.
      -- Se llena con espacios y despues se le ponen las naves,
      -- balas y cannon. Al final se imprime todo de una vez.
      Pantalla : array (1 .. ALTO, 1 .. ANCHO) of Character
         := (others => (others => ' '));
   begin
      -- Dibujar naves vivas como <##> (4 caracteres)
      for I in 1 .. TOTAL_NAVES loop
         if Nav (I).Estado = Viva then
            declare
               F : constant Integer := Nav (I).Fila;
               C : constant Integer := Nav (I).Columna;
            begin
               -- Verificar que la nave este dentro de la pantalla
               if F in 1 .. ALTO
                  and then C >= 1
                  and then C + 3 <= ANCHO
               then
                  Pantalla (F, C)     := '<';
                  Pantalla (F, C + 1) := '#';
                  Pantalla (F, C + 2) := '#';
                  Pantalla (F, C + 3) := '>';
               end if;
            end;
         end if;
      end loop;

      -- Dibujar balas activas como !
      for I in 1 .. MAX_BALAS loop
         if Bal (I).Activa then
            declare
               F : constant Integer := Bal (I).Fila;
               C : constant Integer := Bal (I).Columna;
            begin
               if F in 1 .. ALTO and then C in 1 .. ANCHO then
                  Pantalla (F, C) := '!';
               end if;
            end;
         end if;
      end loop;

      -- Dibujar cannon como /^^\ (4 caracteres, apuntando arriba)
      if Canon_Col >= 1 and then Canon_Col + 3 <= ANCHO then
         Pantalla (ALTO, Canon_Col)     := '/';
         Pantalla (ALTO, Canon_Col + 1) := '^';
         Pantalla (ALTO, Canon_Col + 2) := '^';
         Pantalla (ALTO, Canon_Col + 3) := '\';
      end if;

      -- Limpiar pantalla y mover cursor al inicio (codigos ANSI)
      Put (Character'Val (27) & "[2J" & Character'Val (27) & "[H");

      -- Imprimir la pantalla fila por fila
      for F in 1 .. ALTO loop
         for C in 1 .. ANCHO loop
            Put (Pantalla (F, C));
         end loop;
         New_Line;
      end loop;

      -- Linea de estado
      Put ("Naves:" & Integer'Image (Naves_Vivas)
           & " | A/D:mover W:disparar Q:salir");
      New_Line;
   end Dibujar;

   -- Variables para leer el teclado
   Tecla     : Character;
   Hay_Tecla : Boolean;

-- =========================================================
-- CUERPO PRINCIPAL (main)
--
-- En ADA, el main tambien es una task. Las subtasks
-- (naves y balas) arrancan a ejecutar ANTES del begin.
-- El main espera a que todas sus subtasks terminen
-- antes de finalizar (como pthread_join en C).
-- =========================================================
begin
   -- Inicializar las naves: 2 filas de 5, alternadas.
   -- Cada nave recibe su ID y posicion via la cita Iniciar.
   for Fila in 0 .. FILAS_NAVES - 1 loop
      for C in 0 .. NAVES_POR_FILA - 1 loop
         declare
            Id      : constant Integer := Fila * NAVES_POR_FILA + C + 1;
            Fila_P  : constant Integer := 3 + Fila * 3;      -- filas 3 y 6
            Col_P   : constant Integer := 3 + Fila * 4 + C * 12;  -- espaciadas
         begin
            Naves (Id).Iniciar (Id, Fila_P, Col_P);
         end;
      end loop;
   end loop;

   -- Inicializar las balas (darles su ID)
   for I in 1 .. MAX_BALAS loop
      Balas (I).Iniciar_Bala (I);
   end loop;

   -- ======================================================
   -- LOOP PRINCIPAL DEL JUEGO
   -- En cada iteracion: leer teclado, actualizar, dibujar.
   -- ======================================================
   while Juego_Activo loop

      -- Leer input del teclado SIN esperar a que apriete Enter.
      -- OJO: Get_Immediate no se vio en clase, hay que estudiarlo.
      -- La version con Hay_Tecla es NO BLOQUEANTE: si no hay
      -- tecla presionada, Hay_Tecla queda en False y sigue.
      -- Si el usuario presiono una tecla, Hay_Tecla es True
      -- y Tecla tiene el caracter.
      begin
         Get_Immediate (Tecla, Hay_Tecla);
      exception
         when others => Hay_Tecla := False;
      end;

      if Hay_Tecla then

         -- Mover cannon a la izquierda
         if Tecla = 'a' or Tecla = 'A' then
            if Canon_Col > 1 then
               Canon_Col := Canon_Col - 1;
            end if;

         -- Mover cannon a la derecha
         elsif Tecla = 'd' or Tecla = 'D' then
            if Canon_Col + NAVE_ANCHO <= ANCHO then
               Canon_Col := Canon_Col + 1;
            end if;

         -- Disparar: buscar una bala libre y dispararla
         elsif Tecla = 'w' or Tecla = 'W' then
            for I in 1 .. MAX_BALAS loop
               if not Bal (I).Activa then
                  -- Llamar a Disparar con select temporal
                  -- por si la bala no esta lista todavia
                  begin
                     select
                        Balas (I).Disparar (Canon_Col + 2);
                     or
                        delay 0.01;
                     end select;
                  exception
                     when others => null;
                  end;
                  exit;  -- solo disparar una bala por tecla
               end if;
            end loop;

         -- Salir del juego
         elsif Tecla = 'q' or Tecla = 'Q' then
            Juego_Activo := False;
         end if;
      end if;

      -- Actualizar la direccion de movimiento de las naves.
      -- Si la nave mas a la derecha toca el borde, todas van
      -- a la izquierda. Si la mas a la izquierda toca el borde,
      -- todas van a la derecha.
      declare
         Max_C : Integer := 0;
         Min_C : Integer := ANCHO;
      begin
         for I in 1 .. TOTAL_NAVES loop
            if Nav (I).Estado = Viva then
               if Nav (I).Columna + NAVE_ANCHO > Max_C then
                  Max_C := Nav (I).Columna + NAVE_ANCHO;
               end if;
               if Nav (I).Columna < Min_C then
                  Min_C := Nav (I).Columna;
               end if;
            end if;
         end loop;
         if Max_C >= ANCHO then
            Direccion := -1;
         end if;
         if Min_C <= 1 then
            Direccion := 1;
         end if;
      end;

      -- Verificar si gano (todas las naves destruidas)
      if Naves_Vivas <= 0 then
         Juego_Activo := False;
      end if;

      -- Dibujar la pantalla
      Dibujar;

      -- Controlar velocidad del juego (~20 FPS)
      delay 0.05;
   end loop;

   -- Mensaje final
   Put (Character'Val (27) & "[2J" & Character'Val (27) & "[H");
   if Naves_Vivas <= 0 then
      Put_Line ("GANASTE! Todas las naves destruidas.");
   else
      Put_Line ("Juego terminado.");
   end if;

end Space_Invaders;
