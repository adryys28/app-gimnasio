USE App_Gym;
GO

/* =========================================================
   12 - Catálogo de ejercicios por grupo muscular
   Ejecutar después de 01 a 11. Se puede volver a ejecutar.

   - 145 ejercicios en 15 grupos musculares, con pasos de
     ejecución, errores comunes, músculos principales y secundarios,
     material, nivel mínimo y tipo de medida.
   - Añade los grupos musculares y materiales que falten.
   - Los ejercicios que ya existen (por nombre) se actualizan y
     conservan su Id, así que las rutinas no se ven afectadas.
   - Los músculos y materiales de cada ejercicio se sustituyen
     por los de este script.

   El contenido técnico debe revisarlo una persona profesional
   del entrenamiento antes de publicarlo.
   ========================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ---------- Grupos musculares y materiales nuevos ---------- */
INSERT INTO gym.GrupoMuscular (Nombre)
SELECT v.Nombre
FROM (VALUES (N'Trapecio'), (N'Antebrazos'), (N'Lumbares'), (N'Oblicuos'), (N'Aductores')) v(Nombre)
WHERE NOT EXISTS (SELECT 1 FROM gym.GrupoMuscular g WHERE g.Nombre = v.Nombre);

INSERT INTO gym.Material (Nombre)
SELECT v.Nombre
FROM (VALUES (N'Barra Z'), (N'Disco'), (N'Multipower'), (N'Barra de dominadas'), (N'Paralelas'), (N'Cintas de suspensión'), (N'Fitball'), (N'Rueda abdominal'), (N'Banco de hiperextensiones')) v(Nombre)
WHERE NOT EXISTS (SELECT 1 FROM gym.Material m WHERE m.Nombre = v.Nombre);

DECLARE @Ejercicio TABLE (
    Nombre      NVARCHAR(100) NOT NULL PRIMARY KEY,
    Nivel       TINYINT       NOT NULL,
    Tipo        CHAR(1)       NOT NULL,
    Descripcion NVARCHAR(MAX) NOT NULL,
    Errores     NVARCHAR(MAX) NOT NULL
);

DECLARE @Musculo TABLE (
    Ejercicio NVARCHAR(100) NOT NULL,
    Grupo     NVARCHAR(50)  NOT NULL,
    Principal BIT           NOT NULL,
    PRIMARY KEY (Ejercicio, Grupo)
);

DECLARE @Material TABLE (
    Ejercicio NVARCHAR(100) NOT NULL,
    Material  NVARCHAR(50)  NOT NULL,
    PRIMARY KEY (Ejercicio, Material)
);

INSERT INTO @Ejercicio (Nombre, Nivel, Tipo, Descripcion, Errores) VALUES
(N'Press de banca con barra', 2, 'R', N'1. Túmbate en el banco con los ojos bajo la barra y los pies apoyados en el suelo.
2. Agarra la barra algo más abierto que los hombros y sácala del soporte con los brazos extendidos.
3. Bájala controlada hasta rozar la parte media del pecho, con los codos a unos 45° del cuerpo.
4. Empuja hasta extender los brazos sin bloquear los codos de golpe.', N'Rebotar la barra en el pecho.
Abrir los codos a 90° del cuerpo.
Levantar la cadera del banco.'),
(N'Press de banca con mancuernas', 1, 'R', N'1. Túmbate en el banco con una mancuerna en cada mano a la altura del pecho.
2. Empuja hacia arriba hasta extender los brazos, juntando ligeramente las mancuernas.
3. Baja despacio hasta notar estiramiento en el pecho.', N'Bajar demasiado rápido.
Arquear en exceso la zona lumbar.'),
(N'Press inclinado con mancuernas', 2, 'R', N'1. Ajusta el banco a 30-45° y túmbate con una mancuerna en cada mano.
2. Empuja hacia arriba y ligeramente hacia dentro hasta extender los brazos.
3. Baja controlado hasta la altura de la parte alta del pecho.', N'Inclinar demasiado el banco, que traslada el trabajo al hombro.
Separar la espalda del respaldo.'),
(N'Flexiones', 1, 'R', N'1. Apoya las manos algo más abiertas que los hombros y los pies juntos, con el cuerpo en línea recta.
2. Baja el pecho hacia el suelo flexionando los codos a unos 45° del cuerpo.
3. Empuja hasta extender los brazos manteniendo el abdomen firme.
4. Si cuesta, apoya las rodillas o eleva las manos sobre un banco.', N'Hundir o levantar la cadera.
Hacer recorridos cortos.
Adelantar la cabeza.'),
(N'Aperturas con mancuernas', 1, 'R', N'1. Túmbate en el banco con las mancuernas sobre el pecho y los codos ligeramente flexionados.
2. Abre los brazos en arco hasta notar estiramiento en el pecho.
3. Cierra el arco hasta volver arriba sin cambiar el ángulo de los codos.', N'Estirar del todo los codos.
Bajar por debajo de la línea del hombro.'),
(N'Cruce de poleas', 2, 'R', N'1. Colócate entre dos poleas altas con un agarre en cada mano y un pie adelantado.
2. Con los codos ligeramente flexionados, junta las manos delante del cuerpo en un arco descendente.
3. Vuelve despacio a la posición inicial.', N'Convertir el movimiento en un empuje flexionando los codos.
Balancear el tronco.'),
(N'Fondos en paralelas', 2, 'R', N'1. Sujétate en las paralelas con los brazos extendidos.
2. Inclina ligeramente el tronco hacia delante y baja flexionando los codos hasta unos 90°.
3. Empuja hasta extender los brazos.', N'Bajar más de lo que permite el hombro.
Encoger los hombros hacia las orejas.'),
(N'Dominadas', 2, 'R', N'1. Cuélgate de la barra con agarre prono algo más abierto que los hombros.
2. Tira llevando los codos hacia las costillas hasta que la barbilla supere la barra.
3. Baja controlado hasta extender los brazos.', N'Balancear el cuerpo para subir.
Hacer medio recorrido.'),
(N'Jalón al pecho', 1, 'R', N'1. Siéntate en la máquina con los muslos bajo el soporte y agarra la barra algo más abierto que los hombros.
2. Tira de la barra hacia la parte alta del pecho llevando los codos hacia abajo.
3. Sube controlado hasta extender los brazos.', N'Echar el tronco muy atrás.
Tirar de la barra por detrás de la nuca.'),
(N'Remo con mancuerna', 1, 'R', N'1. Apoya la rodilla y la mano del mismo lado en el banco, con la espalda neutra.
2. Sujeta la mancuerna con el brazo extendido, bajo el hombro.
3. Lleva el codo hacia la cadera hasta que la mancuerna quede a la altura del torso.
4. Baja de forma controlada hasta extender el brazo.', N'Girar el tronco para ayudarte a subir el peso.
Encoger el hombro hacia la oreja al tirar.
Redondear la espalda durante el movimiento.'),
(N'Remo con barra', 2, 'R', N'1. De pie, inclina el tronco unos 45° con las rodillas algo flexionadas y la espalda neutra.
2. Sujeta la barra con los brazos extendidos y tira hacia el abdomen.
3. Baja controlado sin cambiar la inclinación del tronco.', N'Redondear la espalda.
Incorporar el tronco para mover más peso.'),
(N'Remo sentado en polea', 1, 'R', N'1. Siéntate con los pies apoyados y las rodillas algo flexionadas, con el agarre en las manos.
2. Tira hacia el abdomen juntando las escápulas, con el tronco erguido.
3. Vuelve extendiendo los brazos sin dejar caer el peso.', N'Balancear el tronco adelante y atrás.
Encoger los hombros.'),
(N'Jalón con brazos rectos en polea', 2, 'R', N'1. De pie frente a la polea alta, sujeta la barra con los brazos casi extendidos.
2. Lleva la barra en arco hasta los muslos sin flexionar los codos.
3. Vuelve controlado hasta la altura de la cabeza.', N'Flexionar los codos y convertirlo en un empuje.
Arquear la zona lumbar.'),
(N'Press militar con mancuernas', 1, 'R', N'1. Sentado o de pie, sujeta las mancuernas a la altura de los hombros.
2. Empuja hacia arriba hasta extender los brazos sobre la cabeza.
3. Baja controlado hasta la altura de los hombros.', N'Arquear la zona lumbar.
Bajar solo hasta media altura.'),
(N'Press militar con barra', 2, 'R', N'1. De pie, sujeta la barra a la altura de las clavículas con los codos ligeramente adelantados.
2. Empuja en vertical, apartando la cabeza, hasta extender los brazos.
3. Baja controlado a la posición inicial.', N'Arquear la espalda para empujar.
Llevar la barra por delante en lugar de en vertical.'),
(N'Elevaciones laterales con mancuernas', 1, 'R', N'1. De pie, con una mancuerna en cada mano a los lados y los codos algo flexionados.
2. Eleva los brazos hacia los lados hasta la altura de los hombros.
3. Baja despacio.', N'Subir por encima de los hombros.
Usar impulso del tronco.'),
(N'Elevaciones frontales con mancuernas', 1, 'R', N'1. De pie, con las mancuernas delante de los muslos.
2. Eleva los brazos al frente hasta la altura de los hombros.
3. Baja controlado.', N'Balancear el cuerpo.
Subir por encima de la cabeza.'),
(N'Pájaros con mancuernas', 1, 'R', N'1. Inclina el tronco hacia delante con la espalda neutra y una mancuerna en cada mano.
2. Abre los brazos hacia los lados con los codos algo flexionados.
3. Baja despacio.', N'Incorporar el tronco al subir.
Encoger los hombros.'),
(N'Face pull en polea', 1, 'R', N'1. Coloca la cuerda en la polea a la altura de la cara.
2. Tira hacia la cara separando las manos y llevando los codos altos y atrás.
3. Vuelve controlado.', N'Tirar con los codos bajos.
Echar el cuerpo atrás.'),
(N'Curl de bíceps con mancuernas', 1, 'R', N'1. De pie, con una mancuerna en cada mano y las palmas hacia delante.
2. Flexiona los codos llevando las mancuernas hacia los hombros, sin mover los codos.
3. Baja despacio hasta extender los brazos.', N'Balancear el cuerpo.
Adelantar los codos al subir.'),
(N'Curl de bíceps con barra', 1, 'R', N'1. De pie, sujeta la barra con las palmas hacia delante a la anchura de los hombros.
2. Flexiona los codos hasta llevar la barra al pecho.
3. Baja controlado.', N'Ayudarte con la cadera.
Hacer recorridos cortos.'),
(N'Curl martillo', 1, 'R', N'1. De pie, con las mancuernas a los lados y las palmas enfrentadas.
2. Flexiona los codos sin girar las muñecas.
3. Baja despacio.', N'Mover los codos hacia delante.
Balancear el tronco.'),
(N'Curl de bíceps en polea baja', 1, 'R', N'1. De pie frente a la polea baja, sujeta la barra con las palmas hacia arriba.
2. Flexiona los codos manteniéndolos pegados al cuerpo.
3. Vuelve controlado.', N'Inclinar el cuerpo hacia atrás.
Separar los codos del tronco.'),
(N'Curl de bíceps con banda elástica', 1, 'R', N'1. Pisa la banda con los pies a la anchura de la cadera y sujeta los extremos.
2. Flexiona los codos hacia los hombros.
3. Baja despacio resistiendo la tensión de la banda.', N'Soltar la banda de golpe al bajar.
Mover los codos.'),
(N'Extensión de tríceps en polea alta', 1, 'R', N'1. De pie frente a la polea alta, sujeta la barra o la cuerda con los codos pegados al cuerpo.
2. Extiende los codos hasta estirar los brazos.
3. Vuelve despacio sin separar los codos.', N'Separar los codos del cuerpo.
Inclinarse sobre la polea para empujar con el tronco.'),
(N'Press francés con barra', 2, 'R', N'1. Túmbate en el banco con la barra sobre el pecho y los brazos extendidos.
2. Flexiona solo los codos bajando la barra hacia la frente.
3. Extiende los codos para volver arriba.', N'Abrir los codos hacia fuera.
Mover los hombros durante el ejercicio.'),
(N'Extensión de tríceps por encima de la cabeza', 1, 'R', N'1. Sentado o de pie, sujeta una mancuerna con las dos manos sobre la cabeza.
2. Baja la mancuerna por detrás de la cabeza flexionando los codos.
3. Extiende los codos para subir.', N'Abrir los codos.
Arquear la zona lumbar.'),
(N'Fondos en banco', 1, 'R', N'1. Apoya las manos en el borde del banco a tu espalda, con las piernas estiradas o flexionadas.
2. Baja la cadera flexionando los codos hasta unos 90°.
3. Empuja hasta extender los brazos.', N'Bajar más de lo que permite el hombro.
Separar la espalda del banco.'),
(N'Press de banca con agarre cerrado', 2, 'R', N'1. Túmbate en el banco y agarra la barra a la anchura de los hombros.
2. Baja la barra hacia la parte baja del pecho con los codos pegados al cuerpo.
3. Empuja hasta extender los brazos.', N'Juntar demasiado las manos, que carga las muñecas.
Abrir los codos.'),
(N'Sentadilla goblet', 1, 'R', N'1. Sujeta una mancuerna o kettlebell a la altura del pecho, con los pies algo más abiertos que la cadera.
2. Baja flexionando cadera y rodillas, con el pecho erguido.
3. Sube empujando el suelo con todo el pie.', N'Juntar las rodillas hacia dentro.
Levantar los talones.'),
(N'Sentadilla con barra', 2, 'R', N'1. Coloca la barra sobre la parte alta de la espalda y separa los pies a la anchura de los hombros.
2. Baja flexionando cadera y rodillas hasta que los muslos queden al menos paralelos al suelo.
3. Sube manteniendo la espalda neutra y el pecho erguido.', N'Redondear la espalda al bajar.
Juntar las rodillas hacia dentro.
Levantar los talones.'),
(N'Sentadilla con peso corporal', 1, 'R', N'1. De pie, con los pies algo más abiertos que la cadera y los brazos al frente.
2. Baja como si fueras a sentarte, con el pecho erguido.
3. Sube empujando con los talones.', N'Inclinar demasiado el tronco.
Juntar las rodillas.'),
(N'Prensa de piernas', 1, 'R', N'1. Siéntate en la máquina con la espalda apoyada y los pies en la plataforma a la anchura de la cadera.
2. Baja la plataforma flexionando las rodillas sin despegar la zona lumbar del respaldo.
3. Empuja hasta casi extender las piernas.', N'Bloquear las rodillas al final.
Despegar la cadera del asiento al bajar.'),
(N'Zancadas', 1, 'R', N'1. De pie, da un paso largo hacia delante.
2. Baja hasta que ambas rodillas formen unos 90°, con el tronco erguido.
3. Empuja con la pierna delantera para volver y alterna.', N'Dejar que la rodilla delantera se vaya hacia dentro.
Dar pasos demasiado cortos.'),
(N'Sentadilla búlgara', 2, 'R', N'1. Apoya el empeine del pie trasero en un banco y adelanta el otro pie.
2. Baja flexionando la pierna delantera hasta que el muslo quede casi paralelo al suelo.
3. Sube empujando con la pierna delantera.', N'Colocar el pie delantero demasiado cerca del banco.
Inclinar el tronco en exceso.'),
(N'Extensión de cuádriceps en máquina', 1, 'R', N'1. Siéntate con la espalda apoyada y el rodillo sobre los tobillos.
2. Extiende las rodillas hasta estirar las piernas.
3. Baja controlado.', N'Dar tirones al subir.
Levantar la cadera del asiento.'),
(N'Peso muerto rumano con mancuernas', 1, 'R', N'1. De pie, con las mancuernas delante de los muslos y las rodillas algo flexionadas.
2. Lleva la cadera hacia atrás bajando las mancuernas pegadas a las piernas, con la espalda neutra.
3. Sube empujando la cadera hacia delante.', N'Redondear la espalda.
Flexionar demasiado las rodillas y convertirlo en sentadilla.'),
(N'Peso muerto con barra', 2, 'R', N'1. Colócate con la barra sobre la mitad del pie y agárrala a la anchura de los hombros.
2. Con la espalda neutra, empuja el suelo con las piernas y extiende la cadera para levantarla.
3. Baja llevando la cadera atrás y la barra pegada a las piernas.', N'Redondear la espalda.
Separar la barra del cuerpo.
Tirar con los brazos.'),
(N'Curl femoral tumbado en máquina', 1, 'R', N'1. Túmbate boca abajo con el rodillo sobre los tobillos.
2. Flexiona las rodillas llevando los talones hacia los glúteos.
3. Baja despacio.', N'Levantar la cadera del banco.
Bajar sin control.'),
(N'Buenos días con barra', 2, 'R', N'1. Coloca la barra sobre la parte alta de la espalda, con las rodillas algo flexionadas.
2. Inclina el tronco llevando la cadera hacia atrás, con la espalda neutra.
3. Sube extendiendo la cadera.', N'Redondear la espalda.
Usar demasiado peso al empezar.'),
(N'Curl nórdico', 3, 'R', N'1. De rodillas, con los tobillos sujetos por una persona o un soporte.
2. Deja caer el cuerpo hacia delante lo más despacio posible, con la cadera extendida.
3. Frena con las manos al final y vuelve ayudándote si hace falta.', N'Flexionar la cadera al bajar.
Dejarse caer sin controlar.'),
(N'Hip thrust', 1, 'R', N'1. Apoya la parte alta de la espalda en el banco, con la barra sobre la cadera y los pies apoyados.
2. Eleva la cadera hasta que el tronco quede alineado con los muslos.
3. Baja controlado.', N'Arquear la zona lumbar en lugar de extender la cadera.
Colocar los pies demasiado lejos.'),
(N'Puente de glúteos', 1, 'R', N'1. Túmbate boca arriba con las rodillas flexionadas y los pies apoyados.
2. Eleva la cadera apretando los glúteos hasta alinear rodillas, cadera y hombros.
3. Baja despacio.', N'Empujar con la zona lumbar.
Separar las rodillas en exceso.'),
(N'Patada de glúteo en polea', 1, 'R', N'1. Sujeta la tobillera a la polea baja y apóyate con las manos.
2. Lleva la pierna hacia atrás extendiendo la cadera.
3. Vuelve controlado.', N'Arquear la zona lumbar.
Girar la cadera.'),
(N'Abducción de cadera con banda elástica', 1, 'R', N'1. Coloca la banda por encima de las rodillas y adopta media sentadilla.
2. Separa las rodillas contra la resistencia de la banda.
3. Vuelve despacio.', N'Juntar las rodillas de golpe.
Inclinar el tronco.'),
(N'Swing con kettlebell', 2, 'R', N'1. Con los pies algo más abiertos que la cadera, sujeta la kettlebell con las dos manos.
2. Lleva la cadera atrás pasando la kettlebell entre las piernas.
3. Extiende la cadera con fuerza para impulsarla hasta la altura del pecho.', N'Levantarla con los brazos en lugar de con la cadera.
Redondear la espalda.'),
(N'Subidas al banco', 1, 'R', N'1. Colócate frente al banco con una mancuerna en cada mano si quieres carga.
2. Sube apoyando todo el pie en el banco y empujando con esa pierna.
3. Baja controlado y alterna.', N'Impulsarte con la pierna de abajo.
Usar un banco demasiado alto.'),
(N'Elevación de talones de pie', 1, 'R', N'1. De pie, con la parte delantera de los pies sobre un escalón.
2. Sube los talones lo más alto posible.
3. Baja hasta notar estiramiento en el gemelo.', N'Rebotar abajo.
Flexionar las rodillas para ayudarte.'),
(N'Elevación de talones sentado en máquina', 1, 'R', N'1. Siéntate con el soporte sobre los muslos y la parte delantera de los pies en la plataforma.
2. Sube los talones.
3. Baja despacio.', N'Recorridos cortos.
Moverlo con impulso.'),
(N'Elevación de talones en prensa', 1, 'R', N'1. En la prensa, apoya la parte delantera de los pies en el borde inferior de la plataforma con las piernas extendidas.
2. Empuja con las puntas extendiendo los tobillos.
3. Vuelve controlado.', N'Flexionar las rodillas.
Dejar que los pies resbalen de la plataforma.'),
(N'Plancha frontal', 1, 'T', N'1. Apóyate sobre los antebrazos y las puntas de los pies.
2. Mantén el cuerpo en línea recta con el abdomen y los glúteos apretados.
3. Respira con normalidad durante todo el tiempo.', N'Hundir la cadera.
Elevar demasiado la cadera.'),
(N'Plancha lateral', 1, 'T', N'1. Túmbate de lado y apóyate sobre el antebrazo y el borde del pie.
2. Eleva la cadera hasta alinear el cuerpo.
3. Mantén la posición y cambia de lado.', N'Dejar caer la cadera.
Girar el tronco hacia delante.'),
(N'Crunch abdominal', 1, 'R', N'1. Túmbate boca arriba con las rodillas flexionadas.
2. Eleva los hombros del suelo acercando las costillas a la cadera.
3. Baja despacio.', N'Tirar del cuello con las manos.
Despegar toda la espalda del suelo.'),
(N'Dead bug', 1, 'R', N'1. Túmbate boca arriba con brazos hacia el techo y rodillas a 90°.
2. Extiende a la vez un brazo y la pierna contraria sin despegar la zona lumbar del suelo.
3. Vuelve y alterna.', N'Arquear la zona lumbar.
Moverse demasiado rápido.'),
(N'Elevación de piernas colgado', 2, 'R', N'1. Cuélgate de una barra con los brazos extendidos.
2. Eleva las piernas llevando la pelvis hacia arriba.
3. Baja controlado sin balancearte.', N'Balancear el cuerpo.
Subir solo con la flexión de cadera.'),
(N'Pallof press', 1, 'R', N'1. De lado a la polea o a la banda, sujeta el agarre a la altura del pecho.
2. Extiende los brazos al frente resistiendo el giro del tronco.
3. Vuelve al pecho y cambia de lado.', N'Girar el tronco hacia la polea.
Arquear la zona lumbar.'),
(N'Press inclinado con barra', 2, 'R', N'1. Ajusta el banco a 30-45° y sujeta la barra algo más abierto que los hombros.
2. Bájala controlada hasta la parte alta del pecho.
3. Empuja hasta extender los brazos.', N'Inclinar demasiado el banco.
Rebotar la barra en el pecho.'),
(N'Press declinado con barra', 2, 'R', N'1. Túmbate en el banco declinado con los pies sujetos.
2. Baja la barra hasta la parte baja del pecho.
3. Empuja hasta extender los brazos.', N'Bajar la barra hacia el cuello.
Abrir los codos en exceso.'),
(N'Press de pecho en máquina', 1, 'R', N'1. Ajusta el asiento para que los agarres queden a la altura del pecho.
2. Empuja hasta casi extender los brazos.
3. Vuelve despacio sin dejar que las placas choquen.', N'Despegar la espalda del respaldo.
Bloquear los codos al final.'),
(N'Press de banca en multipower', 1, 'R', N'1. Coloca el banco bajo la barra de forma que baje a la altura media del pecho.
2. Desbloquea la barra y bájala controlada.
3. Empuja hasta extender los brazos y vuelve a bloquearla al terminar.', N'Colocar el banco desplazado respecto a la barra.
Rebotar en el pecho.'),
(N'Aperturas en máquina', 1, 'R', N'1. Siéntate con la espalda apoyada y sujeta los agarres a la altura del pecho.
2. Junta los brazos delante del cuerpo con los codos algo flexionados.
3. Vuelve despacio hasta notar estiramiento.', N'Separar la espalda del respaldo.
Abrir más de lo que permite el hombro.'),
(N'Aperturas inclinadas con mancuernas', 1, 'R', N'1. Túmbate en el banco inclinado a 30° con las mancuernas sobre el pecho.
2. Abre los brazos en arco con los codos algo flexionados.
3. Cierra el arco hasta volver arriba.', N'Estirar del todo los codos.
Bajar demasiado las mancuernas.'),
(N'Flexiones inclinadas', 1, 'R', N'1. Apoya las manos en un banco y los pies en el suelo, con el cuerpo recto.
2. Baja el pecho hacia el banco.
3. Empuja hasta extender los brazos.', N'Hundir la cadera.
Hacer recorridos cortos.'),
(N'Flexiones declinadas', 2, 'R', N'1. Apoya los pies en un banco y las manos en el suelo.
2. Baja el pecho hacia el suelo con el cuerpo recto.
3. Empuja hasta extender los brazos.', N'Arquear la zona lumbar.
Adelantar la cabeza.'),
(N'Flexiones en cintas de suspensión', 2, 'R', N'1. Sujeta las asas con los brazos extendidos y el cuerpo inclinado y recto.
2. Baja el pecho entre las manos controlando que las cintas no se abran.
3. Empuja hasta extender los brazos.', N'Dejar que las asas se separen.
Hundir la cadera.'),
(N'Pullover con mancuerna', 2, 'R', N'1. Túmbate en el banco sujetando una mancuerna con las dos manos sobre el pecho.
2. Lleva la mancuerna por detrás de la cabeza en arco, con los codos algo flexionados.
3. Vuelve a la posición inicial.', N'Flexionar demasiado los codos.
Arquear en exceso la espalda.'),
(N'Dominadas supinas', 2, 'R', N'1. Cuélgate con las palmas hacia ti y las manos a la anchura de los hombros.
2. Tira hasta que la barbilla supere la barra.
3. Baja controlado hasta extender los brazos.', N'Balancearse.
Hacer medio recorrido.'),
(N'Dominadas asistidas con banda', 1, 'R', N'1. Pasa la banda por la barra y apoya en ella una rodilla o un pie.
2. Tira hasta que la barbilla supere la barra.
3. Baja controlado.', N'Dejarse caer al bajar.
Usar una banda tan fuerte que no exija esfuerzo.'),
(N'Jalón con agarre estrecho', 1, 'R', N'1. Sujeta el agarre estrecho con las palmas enfrentadas.
2. Tira hacia la parte alta del abdomen llevando los codos pegados al cuerpo.
3. Sube controlado.', N'Echar el tronco atrás en exceso.
Encoger los hombros.'),
(N'Remo en máquina', 1, 'R', N'1. Siéntate con el pecho apoyado en el soporte y sujeta los agarres.
2. Tira llevando los codos atrás y juntando las escápulas.
3. Vuelve despacio.', N'Separar el pecho del soporte.
Tirar solo con los brazos.'),
(N'Remo unilateral en polea', 1, 'R', N'1. De pie o sentado frente a la polea, sujeta el agarre con una mano.
2. Tira hacia la cadera llevando el codo atrás.
3. Vuelve extendiendo el brazo y cambia de lado.', N'Girar el tronco.
Encoger el hombro.'),
(N'Remo invertido en cintas de suspensión', 1, 'R', N'1. Sujeta las asas y échate hacia atrás con el cuerpo recto.
2. Tira del pecho hacia las manos juntando las escápulas.
3. Baja controlado.', N'Hundir la cadera.
Tirar con impulso.'),
(N'Remo invertido en multipower', 1, 'R', N'1. Coloca la barra a la altura de la cadera y túmbate debajo sujetándola.
2. Con el cuerpo recto, tira del pecho hacia la barra.
3. Baja controlado.', N'Hundir la cadera.
Hacer recorridos cortos.'),
(N'Remo en punta con barra', 2, 'R', N'1. Fija un extremo de la barra y colócate a horcajadas sobre el otro.
2. Con el tronco inclinado y la espalda neutra, tira de la barra hacia el pecho.
3. Baja controlado.', N'Redondear la espalda.
Incorporar el tronco al tirar.'),
(N'Remo Pendlay', 3, 'R', N'1. Con el tronco paralelo al suelo, sujeta la barra apoyada en el suelo.
2. Tira de forma explosiva hasta el abdomen.
3. Devuelve la barra al suelo en cada repetición.', N'Levantar el tronco al tirar.
Redondear la espalda.'),
(N'Remo con banda elástica', 1, 'R', N'1. Sujeta la banda a un punto fijo a la altura del pecho.
2. Tira llevando los codos atrás y juntando las escápulas.
3. Vuelve despacio.', N'Soltar la tensión de golpe.
Encoger los hombros.'),
(N'Hiperextensiones', 1, 'R', N'1. Colócate en el banco con la cadera en el borde del apoyo y los talones sujetos.
2. Baja el tronco con la espalda neutra.
3. Sube hasta alinear tronco y piernas, sin pasar de esa línea.', N'Hiperextender la espalda al subir.
Bajar con la espalda redondeada.'),
(N'Superman', 1, 'R', N'1. Túmbate boca abajo con los brazos extendidos al frente.
2. Eleva a la vez brazos y piernas unos centímetros.
3. Mantén un segundo y baja despacio.', N'Elevar en exceso forzando la zona lumbar.
Levantar la cabeza.'),
(N'Bird dog', 1, 'R', N'1. En cuadrupedia, con las manos bajo los hombros y las rodillas bajo la cadera.
2. Extiende a la vez un brazo y la pierna contraria sin mover la cadera.
3. Vuelve y alterna.', N'Girar la cadera.
Arquear la zona lumbar.'),
(N'Encogimientos con barra', 1, 'R', N'1. De pie, sujeta la barra delante de los muslos con los brazos extendidos.
2. Eleva los hombros hacia las orejas.
3. Baja despacio.', N'Girar los hombros.
Flexionar los codos.'),
(N'Encogimientos con mancuernas', 1, 'R', N'1. De pie, con una mancuerna en cada mano a los lados.
2. Eleva los hombros hacia las orejas.
3. Baja despacio.', N'Mover la cabeza.
Hacer recorridos cortos.'),
(N'Remo al mentón con barra', 2, 'R', N'1. De pie, sujeta la barra delante de los muslos algo más abierto que los hombros.
2. Sube la barra pegada al cuerpo llevando los codos hacia los lados hasta la altura del pecho.
3. Baja controlado.', N'Subir los codos por encima de los hombros si molesta.
Agarrar demasiado cerrado.'),
(N'Paseo del granjero', 1, 'T', N'1. Sujeta una carga pesada en cada mano a los lados del cuerpo.
2. Camina con pasos cortos, el tronco erguido y los hombros atrás.
3. Mantén el agarre durante todo el tiempo.', N'Inclinarse hacia un lado.
Encoger los hombros.'),
(N'Press Arnold', 2, 'R', N'1. Sentado, con las mancuernas delante de la cara y las palmas hacia ti.
2. Empuja hacia arriba girando las palmas hasta que miren al frente.
3. Baja deshaciendo el giro.', N'Arquear la zona lumbar.
Hacer el giro con prisa.'),
(N'Press de hombro en máquina', 1, 'R', N'1. Ajusta el asiento para que los agarres queden a la altura de los hombros.
2. Empuja hasta casi extender los brazos.
3. Baja controlado.', N'Separar la espalda del respaldo.
Bloquear los codos.'),
(N'Elevaciones laterales en polea', 1, 'R', N'1. De lado a la polea baja, sujeta el agarre con la mano contraria.
2. Eleva el brazo hacia el lado hasta la altura del hombro.
3. Baja despacio y cambia de lado.', N'Subir por encima del hombro.
Inclinar el tronco.'),
(N'Pájaros en máquina', 1, 'R', N'1. Siéntate de cara al respaldo y sujeta los agarres con los brazos al frente.
2. Abre los brazos hacia atrás a la altura de los hombros.
3. Vuelve despacio.', N'Encoger los hombros.
Separar el pecho del respaldo.'),
(N'Rotación externa de hombro con banda', 1, 'R', N'1. Sujeta la banda con el codo pegado al cuerpo y flexionado a 90°.
2. Gira el antebrazo hacia fuera sin separar el codo.
3. Vuelve despacio y cambia de lado.', N'Separar el codo del cuerpo.
Usar una resistencia excesiva.'),
(N'Flexiones en pica', 2, 'R', N'1. Colócate en forma de V invertida con las manos y los pies en el suelo.
2. Baja la cabeza hacia el suelo flexionando los codos.
3. Empuja hasta extender los brazos.', N'Abrir los codos hacia los lados.
Bajar la cadera durante el movimiento.'),
(N'Curl con barra Z', 1, 'R', N'1. De pie, sujeta la barra Z por la parte angulada con las palmas hacia delante.
2. Flexiona los codos hasta llevar la barra al pecho.
3. Baja controlado.', N'Balancear el cuerpo.
Adelantar los codos.'),
(N'Curl concentrado', 1, 'R', N'1. Sentado en el banco, apoya el codo en la cara interna del muslo.
2. Flexiona el codo llevando la mancuerna hacia el hombro.
3. Baja despacio y cambia de lado.', N'Mover el hombro.
Hacer recorridos cortos.'),
(N'Curl predicador con barra Z', 1, 'R', N'1. Apoya la parte posterior de los brazos en el banco predicador.
2. Flexiona los codos llevando la barra hacia los hombros.
3. Baja controlado sin extender del todo de golpe.', N'Levantar los codos del apoyo.
Dejar caer la barra al bajar.'),
(N'Curl inclinado con mancuernas', 2, 'R', N'1. Siéntate en un banco inclinado a 45° con los brazos colgando.
2. Flexiona los codos sin adelantarlos.
3. Baja despacio hasta estirar los brazos.', N'Separar la espalda del respaldo.
Adelantar los codos.'),
(N'Curl araña', 2, 'R', N'1. Túmbate boca abajo en un banco inclinado con los brazos colgando.
2. Flexiona los codos llevando las mancuernas hacia los hombros.
3. Baja controlado.', N'Mover los hombros.
Balancear las mancuernas.'),
(N'Curl de bíceps en máquina', 1, 'R', N'1. Ajusta el asiento para que los codos queden alineados con el eje de la máquina.
2. Flexiona los codos.
3. Vuelve despacio.', N'Levantar los codos del apoyo.
Hacer el movimiento con impulso.'),
(N'Curl martillo con cuerda en polea', 1, 'R', N'1. De pie frente a la polea baja, sujeta la cuerda con las palmas enfrentadas.
2. Flexiona los codos pegados al cuerpo.
3. Vuelve controlado.', N'Separar los codos.
Inclinarse hacia atrás.'),
(N'Curl de muñeca con barra', 1, 'R', N'1. Sentado, apoya los antebrazos en los muslos o en el banco con las palmas hacia arriba.
2. Flexiona las muñecas elevando la barra.
3. Baja despacio.', N'Mover los antebrazos.
Usar demasiado peso.'),
(N'Curl de muñeca invertido', 1, 'R', N'1. Apoya los antebrazos con las palmas hacia abajo.
2. Extiende las muñecas elevando la carga.
3. Baja despacio.', N'Mover los antebrazos.
Hacer recorridos cortos.'),
(N'Curl invertido con barra Z', 1, 'R', N'1. De pie, sujeta la barra con las palmas hacia abajo.
2. Flexiona los codos hasta llevar la barra al pecho.
3. Baja controlado.', N'Doblar las muñecas.
Balancear el cuerpo.'),
(N'Colgarse de la barra', 1, 'T', N'1. Agárrate a la barra con los brazos extendidos.
2. Mantén el cuerpo quieto y los hombros activos, sin dejarlos caer del todo.
3. Aguanta el tiempo indicado.', N'Balancearse.
Relajar por completo los hombros.'),
(N'Extensión de tríceps con cuerda en polea', 1, 'R', N'1. De pie frente a la polea alta, sujeta la cuerda con los codos pegados al cuerpo.
2. Extiende los codos separando los extremos de la cuerda al final.
3. Vuelve despacio.', N'Separar los codos.
Empujar con el tronco.'),
(N'Extensión de tríceps tras nuca en polea', 1, 'R', N'1. De espaldas a la polea, sujeta la cuerda por detrás de la cabeza.
2. Extiende los codos llevando las manos al frente y arriba.
3. Vuelve controlado.', N'Abrir los codos.
Arquear la zona lumbar.'),
(N'Patada de tríceps con mancuerna', 1, 'R', N'1. Apóyate en el banco con el tronco inclinado y el codo pegado al cuerpo.
2. Extiende el codo llevando la mancuerna hacia atrás.
3. Vuelve despacio y cambia de lado.', N'Bajar el codo durante el movimiento.
Balancear la mancuerna.'),
(N'Press francés con barra Z', 1, 'R', N'1. Túmbate en el banco con la barra Z sobre el pecho y los brazos extendidos.
2. Flexiona los codos bajando la barra hacia la frente.
3. Extiende los codos para subir.', N'Abrir los codos.
Mover los hombros.'),
(N'Flexiones diamante', 2, 'R', N'1. Apoya las manos juntas bajo el pecho formando un rombo con pulgares e índices.
2. Baja el pecho hacia las manos con los codos pegados al cuerpo.
3. Empuja hasta extender los brazos.', N'Abrir los codos.
Hundir la cadera.'),
(N'Fondos en máquina', 1, 'R', N'1. Siéntate con la espalda apoyada y sujeta los agarres a los lados.
2. Empuja hacia abajo hasta extender los brazos.
3. Vuelve despacio.', N'Encoger los hombros.
Inclinarse hacia delante.'),
(N'Sentadilla frontal con barra', 3, 'R', N'1. Apoya la barra sobre la parte delantera de los hombros con los codos altos.
2. Baja con el tronco erguido hasta que los muslos queden paralelos al suelo o más abajo.
3. Sube manteniendo los codos altos.', N'Dejar caer los codos.
Inclinar el tronco hacia delante.'),
(N'Sentadilla en multipower', 1, 'R', N'1. Coloca la barra sobre la parte alta de la espalda y los pies ligeramente adelantados.
2. Baja flexionando cadera y rodillas.
3. Sube empujando con todo el pie.', N'Colocar los pies justo debajo de la barra.
Juntar las rodillas.'),
(N'Sentadilla hack', 2, 'R', N'1. Apoya la espalda y los hombros en la máquina con los pies a la anchura de la cadera.
2. Baja flexionando las rodillas de forma controlada.
3. Sube sin bloquear las rodillas.', N'Despegar la zona lumbar del respaldo.
Juntar las rodillas.'),
(N'Zancadas hacia atrás', 1, 'R', N'1. De pie, da un paso largo hacia atrás.
2. Baja hasta que ambas rodillas formen unos 90°.
3. Vuelve empujando con la pierna delantera y alterna.', N'Dejar caer la rodilla trasera de golpe.
Inclinar el tronco.'),
(N'Zancadas caminando', 1, 'R', N'1. Con una mancuerna en cada mano, da un paso largo hacia delante.
2. Baja hasta que ambas rodillas formen unos 90°.
3. Avanza con la otra pierna encadenando zancadas.', N'Pasos demasiado cortos.
Rodilla delantera hacia dentro.'),
(N'Sentadilla a una pierna', 3, 'R', N'1. De pie sobre una pierna, con la otra extendida al frente.
2. Baja controlado todo lo que permita tu movilidad.
3. Sube sin apoyar la otra pierna.', N'Rodilla hacia dentro.
Dejarse caer al bajar.'),
(N'Sissy squat', 3, 'R', N'1. De pie, sujétate a un apoyo y eleva los talones.
2. Inclina el cuerpo hacia atrás mientras adelantas las rodillas.
3. Vuelve a la posición inicial.', N'Flexionar la cadera.
Bajar más de lo que permite la rodilla.'),
(N'Sentadilla isométrica en pared', 1, 'T', N'1. Apoya la espalda en la pared y baja hasta que las rodillas formen unos 90°.
2. Mantén la posición con el peso repartido en todo el pie.
3. Aguanta el tiempo indicado.', N'Apoyar las manos en las piernas.
Separar la espalda de la pared.'),
(N'Sentadilla con salto', 2, 'R', N'1. Baja a media sentadilla con los brazos atrás.
2. Salta con fuerza extendiendo cadera, rodillas y tobillos.
3. Aterriza suave flexionando las piernas.', N'Aterrizar con las piernas rígidas.
Rodillas hacia dentro al caer.'),
(N'Curl femoral sentado en máquina', 1, 'R', N'1. Siéntate con el rodillo detrás de los tobillos y el soporte sobre los muslos.
2. Flexiona las rodillas llevando los talones hacia abajo y atrás.
3. Vuelve despacio.', N'Separar la espalda del respaldo.
Bajar sin control.'),
(N'Peso muerto rumano con barra', 2, 'R', N'1. De pie, sujeta la barra delante de los muslos con las rodillas algo flexionadas.
2. Lleva la cadera atrás bajando la barra pegada a las piernas, con la espalda neutra.
3. Sube empujando la cadera hacia delante.', N'Redondear la espalda.
Separar la barra de las piernas.'),
(N'Peso muerto a una pierna con mancuerna', 2, 'R', N'1. De pie sobre una pierna, con una mancuerna en la mano contraria.
2. Inclina el tronco llevando la otra pierna atrás en línea con la espalda.
3. Vuelve a la posición inicial y cambia de lado.', N'Girar la cadera.
Redondear la espalda.'),
(N'Curl femoral con fitball', 1, 'R', N'1. Túmbate boca arriba con los talones sobre el fitball y la cadera elevada.
2. Flexiona las rodillas acercando el balón a los glúteos.
3. Vuelve extendiendo las piernas sin bajar la cadera.', N'Dejar caer la cadera.
Hacer el movimiento muy rápido.'),
(N'Hip thrust en máquina', 1, 'R', N'1. Siéntate en la máquina con el cinturón sobre la cadera y los pies apoyados.
2. Eleva la cadera hasta alinear tronco y muslos.
3. Baja controlado.', N'Arquear la zona lumbar.
Empujar con las puntas de los pies.'),
(N'Puente de glúteos a una pierna', 1, 'R', N'1. Túmbate boca arriba con una pierna flexionada y la otra extendida.
2. Eleva la cadera apoyándote en el talón de la pierna flexionada.
3. Baja despacio y cambia de lado.', N'Inclinar la cadera hacia un lado.
Empujar con la zona lumbar.'),
(N'Abducción de cadera en máquina', 1, 'R', N'1. Siéntate con las almohadillas por fuera de las rodillas.
2. Separa las piernas contra la resistencia.
3. Vuelve despacio.', N'Dejar que las placas choquen.
Inclinarse hacia delante.'),
(N'Patada de glúteo en cuadrupedia', 1, 'R', N'1. En cuadrupedia, con la espalda neutra.
2. Eleva una pierna flexionada hacia el techo extendiendo la cadera.
3. Baja despacio y cambia de lado.', N'Arquear la zona lumbar.
Girar la cadera.'),
(N'Peso muerto sumo con barra', 2, 'R', N'1. Separa mucho los pies con las puntas hacia fuera y agarra la barra entre las piernas.
2. Con la espalda neutra, empuja el suelo y extiende cadera y rodillas.
3. Baja controlado con la barra pegada al cuerpo.', N'Rodillas hacia dentro.
Redondear la espalda.'),
(N'Pull-through en polea', 1, 'R', N'1. De espaldas a la polea baja, sujeta la cuerda entre las piernas.
2. Lleva la cadera atrás con la espalda neutra.
3. Extiende la cadera llevándola al frente.', N'Tirar con los brazos.
Flexionar demasiado las rodillas.'),
(N'Paso lateral con banda elástica', 1, 'R', N'1. Coloca la banda por encima de las rodillas o en los tobillos y adopta media sentadilla.
2. Da pasos laterales manteniendo la tensión de la banda.
3. Vuelve en la otra dirección.', N'Juntar los pies del todo.
Incorporarse al caminar.'),
(N'Aducción de cadera en máquina', 1, 'R', N'1. Siéntate con las almohadillas por dentro de las rodillas.
2. Junta las piernas contra la resistencia.
3. Vuelve despacio.', N'Abrir más de lo que permite la flexibilidad.
Dar tirones.'),
(N'Sentadilla sumo con mancuerna', 1, 'R', N'1. Separa mucho los pies con las puntas hacia fuera y sujeta una mancuerna entre las piernas.
2. Baja con el tronco erguido y las rodillas en la línea de los pies.
3. Sube empujando con los talones.', N'Rodillas hacia dentro.
Inclinar el tronco.'),
(N'Aducción en polea', 1, 'R', N'1. De lado a la polea baja, con la tobillera en la pierna más cercana.
2. Lleva la pierna por delante de la otra cruzando la línea media.
3. Vuelve despacio y cambia de lado.', N'Inclinar el tronco.
Usar impulso.'),
(N'Zancada lateral', 1, 'R', N'1. De pie, da un paso amplio hacia un lado.
2. Flexiona esa rodilla manteniendo la otra pierna extendida.
3. Vuelve empujando y alterna.', N'Rodilla por delante del pie.
Redondear la espalda.'),
(N'Plancha de Copenhague', 2, 'T', N'1. Túmbate de lado con el antebrazo en el suelo y el pie de arriba sobre un banco.
2. Eleva la cadera hasta alinear el cuerpo, apoyándote en la pierna de arriba.
3. Mantén la posición y cambia de lado.', N'Dejar caer la cadera.
Empezar con la pierna extendida si aún no hay fuerza suficiente.'),
(N'Elevación de talones a una pierna', 1, 'R', N'1. De pie sobre un escalón con un solo pie, sujetándote a un apoyo.
2. Sube el talón lo más alto posible.
3. Baja hasta notar estiramiento y cambia de lado.', N'Rebotar abajo.
Flexionar la rodilla.'),
(N'Elevación de talones de pie en máquina', 1, 'R', N'1. Coloca los hombros bajo las almohadillas y la parte delantera de los pies en la plataforma.
2. Sube los talones extendiendo los tobillos.
3. Baja despacio.', N'Flexionar las rodillas.
Recorridos cortos.'),
(N'Elevación de talones en multipower', 1, 'R', N'1. Coloca la barra sobre la parte alta de la espalda y la parte delantera de los pies sobre un disco.
2. Sube los talones.
3. Baja controlado.', N'Rebotar abajo.
Flexionar las rodillas.'),
(N'Rueda abdominal', 2, 'R', N'1. De rodillas, sujeta la rueda con los brazos extendidos.
2. Rueda hacia delante manteniendo el abdomen firme y sin arquear la espalda.
3. Vuelve tirando con el abdomen.', N'Arquear la zona lumbar.
Ir más lejos de lo que puedes controlar.'),
(N'Crunch en polea alta', 1, 'R', N'1. De rodillas frente a la polea alta, sujeta la cuerda junto a la cabeza.
2. Flexiona el tronco llevando los codos hacia los muslos.
3. Vuelve despacio.', N'Tirar con los brazos.
Mover la cadera en lugar del tronco.'),
(N'Elevación de piernas tumbado', 1, 'R', N'1. Túmbate boca arriba con las manos bajo la cadera o a los lados.
2. Eleva las piernas extendidas hasta la vertical.
3. Baja despacio sin arquear la espalda.', N'Despegar la zona lumbar del suelo al bajar.
Usar impulso.'),
(N'Crunch inverso', 1, 'R', N'1. Túmbate boca arriba con las rodillas flexionadas a 90°.
2. Eleva la cadera del suelo acercando las rodillas al pecho.
3. Baja despacio.', N'Balancear las piernas.
Tirar del cuello.'),
(N'Posición hueca', 2, 'T', N'1. Túmbate boca arriba con brazos y piernas extendidos.
2. Eleva hombros y piernas pegando la zona lumbar al suelo.
3. Aguanta el tiempo indicado.', N'Despegar la zona lumbar.
Contener la respiración.'),
(N'Escaladores', 1, 'R', N'1. En posición de plancha con los brazos extendidos.
2. Lleva alternativamente las rodillas hacia el pecho.
3. Mantén la cadera estable.', N'Elevar la cadera.
Perder la alineación del cuerpo.'),
(N'Plancha sobre fitball', 2, 'T', N'1. Apoya los antebrazos sobre el fitball y los pies en el suelo, con el cuerpo recto.
2. Mantén la posición sin que el balón se mueva.
3. Aguanta el tiempo indicado.', N'Hundir la cadera.
Encoger los hombros.'),
(N'Rotación rusa', 1, 'R', N'1. Sentado con las rodillas flexionadas y el tronco inclinado hacia atrás.
2. Gira el tronco de un lado a otro llevando las manos o un disco junto a la cadera.
3. Mantén la espalda recta.', N'Redondear la espalda.
Mover solo los brazos.'),
(N'Leñador en polea', 1, 'R', N'1. De lado a la polea alta, sujeta el agarre con las dos manos.
2. Lleva el agarre en diagonal hacia la rodilla contraria girando el tronco.
3. Vuelve controlado y cambia de lado.', N'Tirar solo con los brazos.
Girar la cadera en exceso.'),
(N'Crunch bicicleta', 1, 'R', N'1. Túmbate boca arriba con las manos junto a la cabeza.
2. Acerca un codo a la rodilla contraria mientras extiendes la otra pierna.
3. Alterna de forma controlada.', N'Tirar del cuello.
Hacerlo demasiado rápido.'),
(N'Flexión lateral con mancuerna', 1, 'R', N'1. De pie, con una mancuerna en una mano.
2. Inclina el tronco hacia el lado de la mancuerna.
3. Vuelve a la vertical y cambia de lado.', N'Girar el tronco.
Usar dos mancuernas, que anulan el trabajo.');

INSERT INTO @Musculo (Ejercicio, Grupo, Principal) VALUES
(N'Press de banca con barra', N'Pecho', 1),
(N'Press de banca con barra', N'Tríceps', 0),
(N'Press de banca con barra', N'Hombros', 0),
(N'Press de banca con mancuernas', N'Pecho', 1),
(N'Press de banca con mancuernas', N'Tríceps', 0),
(N'Press de banca con mancuernas', N'Hombros', 0),
(N'Press inclinado con mancuernas', N'Pecho', 1),
(N'Press inclinado con mancuernas', N'Hombros', 0),
(N'Press inclinado con mancuernas', N'Tríceps', 0),
(N'Flexiones', N'Pecho', 1),
(N'Flexiones', N'Tríceps', 0),
(N'Flexiones', N'Hombros', 0),
(N'Aperturas con mancuernas', N'Pecho', 1),
(N'Aperturas con mancuernas', N'Hombros', 0),
(N'Cruce de poleas', N'Pecho', 1),
(N'Cruce de poleas', N'Hombros', 0),
(N'Fondos en paralelas', N'Pecho', 1),
(N'Fondos en paralelas', N'Tríceps', 1),
(N'Fondos en paralelas', N'Hombros', 0),
(N'Dominadas', N'Espalda', 1),
(N'Dominadas', N'Bíceps', 0),
(N'Jalón al pecho', N'Espalda', 1),
(N'Jalón al pecho', N'Bíceps', 0),
(N'Remo con mancuerna', N'Espalda', 1),
(N'Remo con mancuerna', N'Bíceps', 0),
(N'Remo con barra', N'Espalda', 1),
(N'Remo con barra', N'Bíceps', 0),
(N'Remo con barra', N'Lumbares', 0),
(N'Remo sentado en polea', N'Espalda', 1),
(N'Remo sentado en polea', N'Bíceps', 0),
(N'Jalón con brazos rectos en polea', N'Espalda', 1),
(N'Jalón con brazos rectos en polea', N'Tríceps', 0),
(N'Press militar con mancuernas', N'Hombros', 1),
(N'Press militar con mancuernas', N'Tríceps', 0),
(N'Press militar con barra', N'Hombros', 1),
(N'Press militar con barra', N'Tríceps', 0),
(N'Press militar con barra', N'Core', 0),
(N'Elevaciones laterales con mancuernas', N'Hombros', 1),
(N'Elevaciones frontales con mancuernas', N'Hombros', 1),
(N'Pájaros con mancuernas', N'Hombros', 1),
(N'Pájaros con mancuernas', N'Espalda', 0),
(N'Pájaros con mancuernas', N'Trapecio', 0),
(N'Face pull en polea', N'Hombros', 1),
(N'Face pull en polea', N'Espalda', 0),
(N'Face pull en polea', N'Trapecio', 0),
(N'Curl de bíceps con mancuernas', N'Bíceps', 1),
(N'Curl de bíceps con barra', N'Bíceps', 1),
(N'Curl martillo', N'Bíceps', 1),
(N'Curl martillo', N'Antebrazos', 0),
(N'Curl de bíceps en polea baja', N'Bíceps', 1),
(N'Curl de bíceps con banda elástica', N'Bíceps', 1),
(N'Extensión de tríceps en polea alta', N'Tríceps', 1),
(N'Press francés con barra', N'Tríceps', 1),
(N'Extensión de tríceps por encima de la cabeza', N'Tríceps', 1),
(N'Fondos en banco', N'Tríceps', 1),
(N'Fondos en banco', N'Pecho', 0),
(N'Fondos en banco', N'Hombros', 0),
(N'Press de banca con agarre cerrado', N'Tríceps', 1),
(N'Press de banca con agarre cerrado', N'Pecho', 0),
(N'Sentadilla goblet', N'Cuádriceps', 1),
(N'Sentadilla goblet', N'Glúteos', 0),
(N'Sentadilla con barra', N'Cuádriceps', 1),
(N'Sentadilla con barra', N'Glúteos', 0),
(N'Sentadilla con barra', N'Core', 0),
(N'Sentadilla con peso corporal', N'Cuádriceps', 1),
(N'Sentadilla con peso corporal', N'Glúteos', 0),
(N'Prensa de piernas', N'Cuádriceps', 1),
(N'Prensa de piernas', N'Glúteos', 0),
(N'Zancadas', N'Cuádriceps', 1),
(N'Zancadas', N'Glúteos', 0),
(N'Sentadilla búlgara', N'Cuádriceps', 1),
(N'Sentadilla búlgara', N'Glúteos', 0),
(N'Extensión de cuádriceps en máquina', N'Cuádriceps', 1),
(N'Peso muerto rumano con mancuernas', N'Isquiotibiales', 1),
(N'Peso muerto rumano con mancuernas', N'Glúteos', 0),
(N'Peso muerto con barra', N'Isquiotibiales', 1),
(N'Peso muerto con barra', N'Glúteos', 1),
(N'Peso muerto con barra', N'Lumbares', 0),
(N'Peso muerto con barra', N'Espalda', 0),
(N'Peso muerto con barra', N'Cuádriceps', 0),
(N'Peso muerto con barra', N'Trapecio', 0),
(N'Curl femoral tumbado en máquina', N'Isquiotibiales', 1),
(N'Buenos días con barra', N'Isquiotibiales', 1),
(N'Buenos días con barra', N'Glúteos', 0),
(N'Buenos días con barra', N'Lumbares', 0),
(N'Curl nórdico', N'Isquiotibiales', 1),
(N'Hip thrust', N'Glúteos', 1),
(N'Hip thrust', N'Isquiotibiales', 0),
(N'Puente de glúteos', N'Glúteos', 1),
(N'Puente de glúteos', N'Isquiotibiales', 0),
(N'Patada de glúteo en polea', N'Glúteos', 1),
(N'Abducción de cadera con banda elástica', N'Glúteos', 1),
(N'Swing con kettlebell', N'Glúteos', 1),
(N'Swing con kettlebell', N'Isquiotibiales', 0),
(N'Swing con kettlebell', N'Core', 0),
(N'Swing con kettlebell', N'Lumbares', 0),
(N'Subidas al banco', N'Glúteos', 1),
(N'Subidas al banco', N'Cuádriceps', 1),
(N'Elevación de talones de pie', N'Gemelos', 1),
(N'Elevación de talones sentado en máquina', N'Gemelos', 1),
(N'Elevación de talones en prensa', N'Gemelos', 1),
(N'Plancha frontal', N'Core', 1),
(N'Plancha lateral', N'Oblicuos', 1),
(N'Plancha lateral', N'Core', 0),
(N'Plancha lateral', N'Glúteos', 0),
(N'Crunch abdominal', N'Core', 1),
(N'Dead bug', N'Core', 1),
(N'Elevación de piernas colgado', N'Core', 1),
(N'Pallof press', N'Core', 1),
(N'Pallof press', N'Oblicuos', 0),
(N'Press inclinado con barra', N'Pecho', 1),
(N'Press inclinado con barra', N'Hombros', 0),
(N'Press inclinado con barra', N'Tríceps', 0),
(N'Press declinado con barra', N'Pecho', 1),
(N'Press declinado con barra', N'Tríceps', 0),
(N'Press declinado con barra', N'Hombros', 0),
(N'Press de pecho en máquina', N'Pecho', 1),
(N'Press de pecho en máquina', N'Tríceps', 0),
(N'Press de pecho en máquina', N'Hombros', 0),
(N'Press de banca en multipower', N'Pecho', 1),
(N'Press de banca en multipower', N'Tríceps', 0),
(N'Press de banca en multipower', N'Hombros', 0),
(N'Aperturas en máquina', N'Pecho', 1),
(N'Aperturas en máquina', N'Hombros', 0),
(N'Aperturas inclinadas con mancuernas', N'Pecho', 1),
(N'Aperturas inclinadas con mancuernas', N'Hombros', 0),
(N'Flexiones inclinadas', N'Pecho', 1),
(N'Flexiones inclinadas', N'Tríceps', 0),
(N'Flexiones inclinadas', N'Hombros', 0),
(N'Flexiones declinadas', N'Pecho', 1),
(N'Flexiones declinadas', N'Hombros', 0),
(N'Flexiones declinadas', N'Tríceps', 0),
(N'Flexiones en cintas de suspensión', N'Pecho', 1),
(N'Flexiones en cintas de suspensión', N'Tríceps', 0),
(N'Flexiones en cintas de suspensión', N'Hombros', 0),
(N'Flexiones en cintas de suspensión', N'Core', 0),
(N'Pullover con mancuerna', N'Pecho', 1),
(N'Pullover con mancuerna', N'Espalda', 0),
(N'Pullover con mancuerna', N'Tríceps', 0),
(N'Dominadas supinas', N'Espalda', 1),
(N'Dominadas supinas', N'Bíceps', 0),
(N'Dominadas asistidas con banda', N'Espalda', 1),
(N'Dominadas asistidas con banda', N'Bíceps', 0),
(N'Jalón con agarre estrecho', N'Espalda', 1),
(N'Jalón con agarre estrecho', N'Bíceps', 0),
(N'Remo en máquina', N'Espalda', 1),
(N'Remo en máquina', N'Bíceps', 0),
(N'Remo unilateral en polea', N'Espalda', 1),
(N'Remo unilateral en polea', N'Bíceps', 0),
(N'Remo invertido en cintas de suspensión', N'Espalda', 1),
(N'Remo invertido en cintas de suspensión', N'Bíceps', 0),
(N'Remo invertido en cintas de suspensión', N'Core', 0),
(N'Remo invertido en multipower', N'Espalda', 1),
(N'Remo invertido en multipower', N'Bíceps', 0),
(N'Remo invertido en multipower', N'Core', 0),
(N'Remo en punta con barra', N'Espalda', 1),
(N'Remo en punta con barra', N'Bíceps', 0),
(N'Remo en punta con barra', N'Lumbares', 0),
(N'Remo Pendlay', N'Espalda', 1),
(N'Remo Pendlay', N'Bíceps', 0),
(N'Remo Pendlay', N'Lumbares', 0),
(N'Remo con banda elástica', N'Espalda', 1),
(N'Remo con banda elástica', N'Bíceps', 0),
(N'Hiperextensiones', N'Lumbares', 1),
(N'Hiperextensiones', N'Glúteos', 0),
(N'Hiperextensiones', N'Isquiotibiales', 0),
(N'Superman', N'Lumbares', 1),
(N'Superman', N'Glúteos', 0),
(N'Bird dog', N'Core', 1),
(N'Bird dog', N'Lumbares', 0),
(N'Bird dog', N'Glúteos', 0),
(N'Encogimientos con barra', N'Trapecio', 1),
(N'Encogimientos con barra', N'Antebrazos', 0),
(N'Encogimientos con mancuernas', N'Trapecio', 1),
(N'Encogimientos con mancuernas', N'Antebrazos', 0),
(N'Remo al mentón con barra', N'Hombros', 1),
(N'Remo al mentón con barra', N'Trapecio', 1),
(N'Remo al mentón con barra', N'Bíceps', 0),
(N'Paseo del granjero', N'Trapecio', 1),
(N'Paseo del granjero', N'Antebrazos', 1),
(N'Paseo del granjero', N'Core', 0),
(N'Press Arnold', N'Hombros', 1),
(N'Press Arnold', N'Tríceps', 0),
(N'Press de hombro en máquina', N'Hombros', 1),
(N'Press de hombro en máquina', N'Tríceps', 0),
(N'Elevaciones laterales en polea', N'Hombros', 1),
(N'Pájaros en máquina', N'Hombros', 1),
(N'Pájaros en máquina', N'Trapecio', 0),
(N'Pájaros en máquina', N'Espalda', 0),
(N'Rotación externa de hombro con banda', N'Hombros', 1),
(N'Flexiones en pica', N'Hombros', 1),
(N'Flexiones en pica', N'Tríceps', 0),
(N'Curl con barra Z', N'Bíceps', 1),
(N'Curl concentrado', N'Bíceps', 1),
(N'Curl predicador con barra Z', N'Bíceps', 1),
(N'Curl inclinado con mancuernas', N'Bíceps', 1),
(N'Curl araña', N'Bíceps', 1),
(N'Curl de bíceps en máquina', N'Bíceps', 1),
(N'Curl martillo con cuerda en polea', N'Bíceps', 1),
(N'Curl martillo con cuerda en polea', N'Antebrazos', 0),
(N'Curl de muñeca con barra', N'Antebrazos', 1),
(N'Curl de muñeca invertido', N'Antebrazos', 1),
(N'Curl invertido con barra Z', N'Antebrazos', 1),
(N'Curl invertido con barra Z', N'Bíceps', 0),
(N'Colgarse de la barra', N'Antebrazos', 1),
(N'Colgarse de la barra', N'Espalda', 0),
(N'Extensión de tríceps con cuerda en polea', N'Tríceps', 1),
(N'Extensión de tríceps tras nuca en polea', N'Tríceps', 1),
(N'Patada de tríceps con mancuerna', N'Tríceps', 1),
(N'Press francés con barra Z', N'Tríceps', 1),
(N'Flexiones diamante', N'Tríceps', 1),
(N'Flexiones diamante', N'Pecho', 0),
(N'Fondos en máquina', N'Tríceps', 1),
(N'Fondos en máquina', N'Pecho', 0),
(N'Sentadilla frontal con barra', N'Cuádriceps', 1),
(N'Sentadilla frontal con barra', N'Glúteos', 0),
(N'Sentadilla frontal con barra', N'Core', 0),
(N'Sentadilla en multipower', N'Cuádriceps', 1),
(N'Sentadilla en multipower', N'Glúteos', 0),
(N'Sentadilla hack', N'Cuádriceps', 1),
(N'Sentadilla hack', N'Glúteos', 0),
(N'Zancadas hacia atrás', N'Cuádriceps', 1),
(N'Zancadas hacia atrás', N'Glúteos', 0),
(N'Zancadas caminando', N'Cuádriceps', 1),
(N'Zancadas caminando', N'Glúteos', 0),
(N'Sentadilla a una pierna', N'Cuádriceps', 1),
(N'Sentadilla a una pierna', N'Glúteos', 0),
(N'Sentadilla a una pierna', N'Core', 0),
(N'Sissy squat', N'Cuádriceps', 1),
(N'Sentadilla isométrica en pared', N'Cuádriceps', 1),
(N'Sentadilla isométrica en pared', N'Glúteos', 0),
(N'Sentadilla con salto', N'Cuádriceps', 1),
(N'Sentadilla con salto', N'Glúteos', 0),
(N'Sentadilla con salto', N'Gemelos', 0),
(N'Curl femoral sentado en máquina', N'Isquiotibiales', 1),
(N'Peso muerto rumano con barra', N'Isquiotibiales', 1),
(N'Peso muerto rumano con barra', N'Glúteos', 0),
(N'Peso muerto rumano con barra', N'Lumbares', 0),
(N'Peso muerto a una pierna con mancuerna', N'Isquiotibiales', 1),
(N'Peso muerto a una pierna con mancuerna', N'Glúteos', 0),
(N'Peso muerto a una pierna con mancuerna', N'Core', 0),
(N'Curl femoral con fitball', N'Isquiotibiales', 1),
(N'Curl femoral con fitball', N'Glúteos', 0),
(N'Hip thrust en máquina', N'Glúteos', 1),
(N'Hip thrust en máquina', N'Isquiotibiales', 0),
(N'Puente de glúteos a una pierna', N'Glúteos', 1),
(N'Puente de glúteos a una pierna', N'Isquiotibiales', 0),
(N'Abducción de cadera en máquina', N'Glúteos', 1),
(N'Patada de glúteo en cuadrupedia', N'Glúteos', 1),
(N'Patada de glúteo en cuadrupedia', N'Isquiotibiales', 0),
(N'Peso muerto sumo con barra', N'Glúteos', 1),
(N'Peso muerto sumo con barra', N'Aductores', 0),
(N'Peso muerto sumo con barra', N'Isquiotibiales', 0),
(N'Peso muerto sumo con barra', N'Cuádriceps', 0),
(N'Pull-through en polea', N'Glúteos', 1),
(N'Pull-through en polea', N'Isquiotibiales', 0),
(N'Paso lateral con banda elástica', N'Glúteos', 1),
(N'Aducción de cadera en máquina', N'Aductores', 1),
(N'Sentadilla sumo con mancuerna', N'Aductores', 1),
(N'Sentadilla sumo con mancuerna', N'Glúteos', 1),
(N'Sentadilla sumo con mancuerna', N'Cuádriceps', 0),
(N'Aducción en polea', N'Aductores', 1),
(N'Zancada lateral', N'Aductores', 1),
(N'Zancada lateral', N'Cuádriceps', 1),
(N'Zancada lateral', N'Glúteos', 0),
(N'Plancha de Copenhague', N'Aductores', 1),
(N'Plancha de Copenhague', N'Oblicuos', 0),
(N'Plancha de Copenhague', N'Core', 0),
(N'Elevación de talones a una pierna', N'Gemelos', 1),
(N'Elevación de talones de pie en máquina', N'Gemelos', 1),
(N'Elevación de talones en multipower', N'Gemelos', 1),
(N'Rueda abdominal', N'Core', 1),
(N'Rueda abdominal', N'Hombros', 0),
(N'Crunch en polea alta', N'Core', 1),
(N'Elevación de piernas tumbado', N'Core', 1),
(N'Crunch inverso', N'Core', 1),
(N'Posición hueca', N'Core', 1),
(N'Escaladores', N'Core', 1),
(N'Escaladores', N'Hombros', 0),
(N'Plancha sobre fitball', N'Core', 1),
(N'Plancha sobre fitball', N'Hombros', 0),
(N'Rotación rusa', N'Oblicuos', 1),
(N'Rotación rusa', N'Core', 0),
(N'Leñador en polea', N'Oblicuos', 1),
(N'Leñador en polea', N'Core', 0),
(N'Crunch bicicleta', N'Oblicuos', 1),
(N'Crunch bicicleta', N'Core', 0),
(N'Flexión lateral con mancuerna', N'Oblicuos', 1);

INSERT INTO @Material (Ejercicio, Material) VALUES
(N'Press de banca con barra', N'Barra'),
(N'Press de banca con barra', N'Banco'),
(N'Press de banca con mancuernas', N'Mancuernas'),
(N'Press de banca con mancuernas', N'Banco'),
(N'Press inclinado con mancuernas', N'Mancuernas'),
(N'Press inclinado con mancuernas', N'Banco'),
(N'Flexiones', N'Peso corporal'),
(N'Aperturas con mancuernas', N'Mancuernas'),
(N'Aperturas con mancuernas', N'Banco'),
(N'Cruce de poleas', N'Polea'),
(N'Fondos en paralelas', N'Paralelas'),
(N'Dominadas', N'Barra de dominadas'),
(N'Jalón al pecho', N'Polea'),
(N'Remo con mancuerna', N'Mancuernas'),
(N'Remo con mancuerna', N'Banco'),
(N'Remo con barra', N'Barra'),
(N'Remo sentado en polea', N'Polea'),
(N'Jalón con brazos rectos en polea', N'Polea'),
(N'Press militar con mancuernas', N'Mancuernas'),
(N'Press militar con barra', N'Barra'),
(N'Elevaciones laterales con mancuernas', N'Mancuernas'),
(N'Elevaciones frontales con mancuernas', N'Mancuernas'),
(N'Pájaros con mancuernas', N'Mancuernas'),
(N'Face pull en polea', N'Polea'),
(N'Curl de bíceps con mancuernas', N'Mancuernas'),
(N'Curl de bíceps con barra', N'Barra'),
(N'Curl martillo', N'Mancuernas'),
(N'Curl de bíceps en polea baja', N'Polea'),
(N'Curl de bíceps con banda elástica', N'Banda elástica'),
(N'Extensión de tríceps en polea alta', N'Polea'),
(N'Press francés con barra', N'Barra'),
(N'Press francés con barra', N'Banco'),
(N'Extensión de tríceps por encima de la cabeza', N'Mancuernas'),
(N'Fondos en banco', N'Banco'),
(N'Fondos en banco', N'Peso corporal'),
(N'Press de banca con agarre cerrado', N'Barra'),
(N'Press de banca con agarre cerrado', N'Banco'),
(N'Sentadilla goblet', N'Mancuernas'),
(N'Sentadilla goblet', N'Kettlebell'),
(N'Sentadilla con barra', N'Barra'),
(N'Sentadilla con peso corporal', N'Peso corporal'),
(N'Prensa de piernas', N'Máquina'),
(N'Zancadas', N'Peso corporal'),
(N'Sentadilla búlgara', N'Mancuernas'),
(N'Sentadilla búlgara', N'Banco'),
(N'Extensión de cuádriceps en máquina', N'Máquina'),
(N'Peso muerto rumano con mancuernas', N'Mancuernas'),
(N'Peso muerto con barra', N'Barra'),
(N'Curl femoral tumbado en máquina', N'Máquina'),
(N'Buenos días con barra', N'Barra'),
(N'Curl nórdico', N'Peso corporal'),
(N'Hip thrust', N'Barra'),
(N'Hip thrust', N'Banco'),
(N'Puente de glúteos', N'Peso corporal'),
(N'Patada de glúteo en polea', N'Polea'),
(N'Abducción de cadera con banda elástica', N'Banda elástica'),
(N'Swing con kettlebell', N'Kettlebell'),
(N'Subidas al banco', N'Banco'),
(N'Subidas al banco', N'Mancuernas'),
(N'Elevación de talones de pie', N'Peso corporal'),
(N'Elevación de talones sentado en máquina', N'Máquina'),
(N'Elevación de talones en prensa', N'Máquina'),
(N'Plancha frontal', N'Peso corporal'),
(N'Plancha lateral', N'Peso corporal'),
(N'Crunch abdominal', N'Peso corporal'),
(N'Dead bug', N'Peso corporal'),
(N'Elevación de piernas colgado', N'Barra de dominadas'),
(N'Pallof press', N'Polea'),
(N'Pallof press', N'Banda elástica'),
(N'Press inclinado con barra', N'Barra'),
(N'Press inclinado con barra', N'Banco'),
(N'Press declinado con barra', N'Barra'),
(N'Press declinado con barra', N'Banco'),
(N'Press de pecho en máquina', N'Máquina'),
(N'Press de banca en multipower', N'Multipower'),
(N'Press de banca en multipower', N'Banco'),
(N'Aperturas en máquina', N'Máquina'),
(N'Aperturas inclinadas con mancuernas', N'Mancuernas'),
(N'Aperturas inclinadas con mancuernas', N'Banco'),
(N'Flexiones inclinadas', N'Banco'),
(N'Flexiones inclinadas', N'Peso corporal'),
(N'Flexiones declinadas', N'Banco'),
(N'Flexiones declinadas', N'Peso corporal'),
(N'Flexiones en cintas de suspensión', N'Cintas de suspensión'),
(N'Pullover con mancuerna', N'Mancuernas'),
(N'Pullover con mancuerna', N'Banco'),
(N'Dominadas supinas', N'Barra de dominadas'),
(N'Dominadas asistidas con banda', N'Barra de dominadas'),
(N'Dominadas asistidas con banda', N'Banda elástica'),
(N'Jalón con agarre estrecho', N'Polea'),
(N'Remo en máquina', N'Máquina'),
(N'Remo unilateral en polea', N'Polea'),
(N'Remo invertido en cintas de suspensión', N'Cintas de suspensión'),
(N'Remo invertido en multipower', N'Multipower'),
(N'Remo en punta con barra', N'Barra'),
(N'Remo en punta con barra', N'Disco'),
(N'Remo Pendlay', N'Barra'),
(N'Remo con banda elástica', N'Banda elástica'),
(N'Hiperextensiones', N'Banco de hiperextensiones'),
(N'Superman', N'Peso corporal'),
(N'Bird dog', N'Peso corporal'),
(N'Encogimientos con barra', N'Barra'),
(N'Encogimientos con mancuernas', N'Mancuernas'),
(N'Remo al mentón con barra', N'Barra'),
(N'Paseo del granjero', N'Mancuernas'),
(N'Paseo del granjero', N'Kettlebell'),
(N'Press Arnold', N'Mancuernas'),
(N'Press Arnold', N'Banco'),
(N'Press de hombro en máquina', N'Máquina'),
(N'Elevaciones laterales en polea', N'Polea'),
(N'Pájaros en máquina', N'Máquina'),
(N'Rotación externa de hombro con banda', N'Banda elástica'),
(N'Flexiones en pica', N'Peso corporal'),
(N'Curl con barra Z', N'Barra Z'),
(N'Curl concentrado', N'Mancuernas'),
(N'Curl concentrado', N'Banco'),
(N'Curl predicador con barra Z', N'Barra Z'),
(N'Curl predicador con barra Z', N'Banco'),
(N'Curl inclinado con mancuernas', N'Mancuernas'),
(N'Curl inclinado con mancuernas', N'Banco'),
(N'Curl araña', N'Mancuernas'),
(N'Curl araña', N'Banco'),
(N'Curl de bíceps en máquina', N'Máquina'),
(N'Curl martillo con cuerda en polea', N'Polea'),
(N'Curl de muñeca con barra', N'Barra'),
(N'Curl de muñeca con barra', N'Banco'),
(N'Curl de muñeca invertido', N'Mancuernas'),
(N'Curl de muñeca invertido', N'Banco'),
(N'Curl invertido con barra Z', N'Barra Z'),
(N'Colgarse de la barra', N'Barra de dominadas'),
(N'Extensión de tríceps con cuerda en polea', N'Polea'),
(N'Extensión de tríceps tras nuca en polea', N'Polea'),
(N'Patada de tríceps con mancuerna', N'Mancuernas'),
(N'Patada de tríceps con mancuerna', N'Banco'),
(N'Press francés con barra Z', N'Barra Z'),
(N'Press francés con barra Z', N'Banco'),
(N'Flexiones diamante', N'Peso corporal'),
(N'Fondos en máquina', N'Máquina'),
(N'Sentadilla frontal con barra', N'Barra'),
(N'Sentadilla en multipower', N'Multipower'),
(N'Sentadilla hack', N'Máquina'),
(N'Zancadas hacia atrás', N'Peso corporal'),
(N'Zancadas hacia atrás', N'Mancuernas'),
(N'Zancadas caminando', N'Mancuernas'),
(N'Sentadilla a una pierna', N'Peso corporal'),
(N'Sissy squat', N'Peso corporal'),
(N'Sentadilla isométrica en pared', N'Peso corporal'),
(N'Sentadilla con salto', N'Peso corporal'),
(N'Curl femoral sentado en máquina', N'Máquina'),
(N'Peso muerto rumano con barra', N'Barra'),
(N'Peso muerto a una pierna con mancuerna', N'Mancuernas'),
(N'Curl femoral con fitball', N'Fitball'),
(N'Hip thrust en máquina', N'Máquina'),
(N'Puente de glúteos a una pierna', N'Peso corporal'),
(N'Abducción de cadera en máquina', N'Máquina'),
(N'Patada de glúteo en cuadrupedia', N'Peso corporal'),
(N'Peso muerto sumo con barra', N'Barra'),
(N'Pull-through en polea', N'Polea'),
(N'Paso lateral con banda elástica', N'Banda elástica'),
(N'Aducción de cadera en máquina', N'Máquina'),
(N'Sentadilla sumo con mancuerna', N'Mancuernas'),
(N'Aducción en polea', N'Polea'),
(N'Zancada lateral', N'Peso corporal'),
(N'Plancha de Copenhague', N'Banco'),
(N'Elevación de talones a una pierna', N'Peso corporal'),
(N'Elevación de talones a una pierna', N'Mancuernas'),
(N'Elevación de talones de pie en máquina', N'Máquina'),
(N'Elevación de talones en multipower', N'Multipower'),
(N'Elevación de talones en multipower', N'Disco'),
(N'Rueda abdominal', N'Rueda abdominal'),
(N'Crunch en polea alta', N'Polea'),
(N'Elevación de piernas tumbado', N'Peso corporal'),
(N'Crunch inverso', N'Peso corporal'),
(N'Posición hueca', N'Peso corporal'),
(N'Escaladores', N'Peso corporal'),
(N'Plancha sobre fitball', N'Fitball'),
(N'Rotación rusa', N'Peso corporal'),
(N'Rotación rusa', N'Disco'),
(N'Leñador en polea', N'Polea'),
(N'Crunch bicicleta', N'Peso corporal'),
(N'Flexión lateral con mancuerna', N'Mancuernas');

/* ---------- Validaciones ---------- */
IF EXISTS (SELECT 1 FROM @Musculo m WHERE NOT EXISTS (SELECT 1 FROM gym.GrupoMuscular g WHERE g.Nombre = m.Grupo))
    THROW 50110, N'Hay grupos musculares que no existen en gym.GrupoMuscular.', 1;
IF EXISTS (SELECT 1 FROM @Material m WHERE NOT EXISTS (SELECT 1 FROM gym.Material x WHERE x.Nombre = m.Material))
    THROW 50111, N'Hay materiales que no existen en gym.Material.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    MERGE gym.Ejercicio AS t
    USING @Ejercicio AS s ON t.Nombre = s.Nombre
    WHEN MATCHED THEN
        UPDATE SET Descripcion    = s.Descripcion,
                   ErroresComunes = s.Errores,
                   NivelMinimoId  = s.Nivel,
                   TipoMedida     = s.Tipo,
                   Activo         = 1
    WHEN NOT MATCHED THEN
        INSERT (Nombre, Descripcion, ErroresComunes, NivelMinimoId, TipoMedida)
        VALUES (s.Nombre, s.Descripcion, s.Errores, s.Nivel, s.Tipo);

    DELETE em
    FROM gym.EjercicioMusculo em
    JOIN gym.Ejercicio e ON e.EjercicioId = em.EjercicioId
    WHERE e.Nombre IN (SELECT Nombre FROM @Ejercicio);

    INSERT INTO gym.EjercicioMusculo (EjercicioId, GrupoMuscularId, EsPrincipal)
    SELECT e.EjercicioId, g.GrupoMuscularId, m.Principal
    FROM @Musculo m
    JOIN gym.Ejercicio e     ON e.Nombre = m.Ejercicio
    JOIN gym.GrupoMuscular g ON g.Nombre = m.Grupo;

    DELETE x
    FROM gym.EjercicioMaterial x
    JOIN gym.Ejercicio e ON e.EjercicioId = x.EjercicioId
    WHERE e.Nombre IN (SELECT Nombre FROM @Ejercicio);

    INSERT INTO gym.EjercicioMaterial (EjercicioId, MaterialId)
    SELECT e.EjercicioId, x.MaterialId
    FROM @Material m
    JOIN gym.Ejercicio e ON e.Nombre = m.Ejercicio
    JOIN gym.Material x  ON x.Nombre = m.Material;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* ---------- Comprobación: ejercicios por grupo muscular ---------- */
SELECT g.Nombre AS GrupoMuscular,
       SUM(CASE WHEN em.EsPrincipal = 1 THEN 1 ELSE 0 END) AS ComoPrincipal,
       SUM(CASE WHEN em.EsPrincipal = 0 THEN 1 ELSE 0 END) AS ComoSecundario
FROM gym.GrupoMuscular g
LEFT JOIN gym.EjercicioMusculo em ON em.GrupoMuscularId = g.GrupoMuscularId
GROUP BY g.Nombre
ORDER BY g.Nombre;

SELECT COUNT(*) AS EjerciciosActivos FROM gym.Ejercicio WHERE Activo = 1;
GO
