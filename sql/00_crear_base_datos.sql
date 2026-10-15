/* =========================================================
   00 - Crear la base de datos App_Gym
   Ejecutar antes que el resto. Los scripts 01 a 11 empiezan
   con USE App_Gym, así que se crean siempre en esta base de datos
   aunque en SSMS esté seleccionada otra.
   ========================================================= */

USE master;
GO

IF DB_ID(N'App_Gym') IS NULL
    CREATE DATABASE App_Gym;
GO

-- OPENJSON requiere nivel >= 130; SQL Server 2022 crea las bases con 160
SELECT name, compatibility_level, collation_name
FROM sys.databases
WHERE name = N'App_Gym';
GO
