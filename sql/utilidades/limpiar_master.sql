/* =========================================================
   Elimina todos los objetos del esquema gym de la base de datos master
   (tablas, procedimientos, funciones, vistas) y el propio esquema.

   1. Ejecutar con @Ejecutar = 0 para ver las sentencias sin borrar nada.
   2. Revisar el listado y volver a ejecutar con @Ejecutar = 1.

   Solo toca objetos del esquema gym: los scripts 01 a 11 no crean
   nada fuera de él. Todo va en una transacción: si algo falla, no
   se borra nada.
   ========================================================= */

USE master;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Ejecutar BIT = 0;  -- 0 = solo mostrar, 1 = borrar

IF DB_NAME() <> N'master'
BEGIN
    RAISERROR(N'Este script solo debe ejecutarse en master.', 16, 1);
    RETURN;
END

IF SCHEMA_ID(N'gym') IS NULL
BEGIN
    PRINT N'El esquema gym no existe en master: no hay nada que borrar.';
    RETURN;
END

DECLARE @Sentencias TABLE (Orden INT, Sentencia NVARCHAR(MAX));

-- 1. Claves foráneas (permiten borrar las tablas en cualquier orden)
INSERT INTO @Sentencias (Orden, Sentencia)
SELECT 1, N'ALTER TABLE gym.' + QUOTENAME(t.name) + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
FROM sys.foreign_keys fk
JOIN sys.tables t ON t.object_id = fk.parent_object_id
WHERE t.schema_id = SCHEMA_ID(N'gym');

-- 2. Procedimientos, 3. vistas, 4. funciones, 5. tablas
INSERT INTO @Sentencias (Orden, Sentencia)
SELECT CASE o.type WHEN 'P' THEN 2 WHEN 'V' THEN 3 WHEN 'U' THEN 5 ELSE 4 END,
       CASE o.type
           WHEN 'P' THEN N'DROP PROCEDURE gym.'
           WHEN 'V' THEN N'DROP VIEW gym.'
           WHEN 'U' THEN N'DROP TABLE gym.'
           ELSE          N'DROP FUNCTION gym.'
       END + QUOTENAME(o.name) + N';'
FROM sys.objects o
WHERE o.schema_id = SCHEMA_ID(N'gym')
  AND o.type IN ('P', 'V', 'U', 'FN', 'IF', 'TF');

-- 6. Esquema
INSERT INTO @Sentencias (Orden, Sentencia) VALUES (6, N'DROP SCHEMA gym;');

IF @Ejecutar = 0
BEGIN
    SELECT Orden, Sentencia FROM @Sentencias ORDER BY Orden, Sentencia;
    PRINT N'Modo vista previa: no se ha borrado nada. Cambia @Ejecutar a 1 para borrar.';
    RETURN;
END

DECLARE @Sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT Sentencia FROM @Sentencias ORDER BY Orden, Sentencia;

BEGIN TRY
    BEGIN TRANSACTION;

    OPEN c;
    FETCH NEXT FROM c INTO @Sql;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM c INTO @Sql;
    END
    CLOSE c;
    DEALLOCATE c;

    COMMIT TRANSACTION;
    PRINT N'Esquema gym eliminado de master.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF CURSOR_STATUS('local', 'c') >= 0 BEGIN CLOSE c; DEALLOCATE c; END;
    THROW;
END CATCH;

-- Comprobación: debe devolver 0 filas
SELECT name, type_desc FROM sys.objects WHERE schema_id = SCHEMA_ID(N'gym');
GO
