/*
    Tailwind Traders SQL Server 2019 sample workload.

    Databases:
      - TailwindRef: small reference data store.
      - TailwindOLTP: transactional retail workload.

    DELIBERATE MIGRATION INCOMPATIBILITY:
      dbo.vwCustomerTaxProfile in TailwindOLTP joins TailwindRef.dbo.Regions
      and TailwindRef.dbo.TaxRates with three-part names. This cross-database
      dependency is intentional so attendees must decide between Azure SQL
      Database remediation and Azure SQL Managed Instance compatibility.
*/

SET NOCOUNT ON;
GO

IF DB_ID(N'TailwindRef') IS NULL
BEGIN
    CREATE DATABASE TailwindRef;
END;
GO

ALTER DATABASE TailwindRef SET COMPATIBILITY_LEVEL = 150;
GO

USE TailwindRef;
GO

IF OBJECT_ID(N'dbo.TaxRates', N'U') IS NOT NULL DROP TABLE dbo.TaxRates;
IF OBJECT_ID(N'dbo.Regions', N'U') IS NOT NULL DROP TABLE dbo.Regions;
GO

CREATE TABLE dbo.Regions
(
    RegionCode char(2) NOT NULL CONSTRAINT PK_Regions PRIMARY KEY,
    RegionName nvarchar(80) NOT NULL,
    SalesRegion nvarchar(40) NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Regions_IsActive DEFAULT (1)
);
GO

CREATE TABLE dbo.TaxRates
(
    RegionCode char(2) NOT NULL,
    TaxCode nvarchar(20) NOT NULL,
    EffectiveFrom date NOT NULL,
    Rate decimal(5,4) NOT NULL,
    CONSTRAINT PK_TaxRates PRIMARY KEY (RegionCode, TaxCode, EffectiveFrom),
    CONSTRAINT FK_TaxRates_Regions FOREIGN KEY (RegionCode)
        REFERENCES dbo.Regions (RegionCode)
);
GO

IF DB_ID(N'TailwindOLTP') IS NULL
BEGIN
    CREATE DATABASE TailwindOLTP;
END;
GO

ALTER DATABASE TailwindOLTP SET COMPATIBILITY_LEVEL = 150;
GO

USE TailwindOLTP;
GO

DROP VIEW IF EXISTS dbo.vwSalesByRegion;
DROP VIEW IF EXISTS dbo.vwCustomerTaxProfile;
DROP PROCEDURE IF EXISTS dbo.usp_GetCustomerOrderSummary;
DROP PROCEDURE IF EXISTS dbo.usp_RunNightlyEtl;
GO

IF OBJECT_ID(N'dbo.OrderLines', N'U') IS NOT NULL DROP TABLE dbo.OrderLines;
IF OBJECT_ID(N'dbo.Orders', N'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID(N'dbo.Inventory', N'U') IS NOT NULL DROP TABLE dbo.Inventory;
IF OBJECT_ID(N'dbo.Products', N'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID(N'dbo.EtlAudit', N'U') IS NOT NULL DROP TABLE dbo.EtlAudit;
IF OBJECT_ID(N'dbo.Customers', N'U') IS NOT NULL DROP TABLE dbo.Customers;
GO

CREATE TABLE dbo.Customers
(
    CustomerId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    CustomerNumber AS (CONVERT(varchar(12), 'C' + RIGHT('000000' + CONVERT(varchar(10), CustomerId), 6))) PERSISTED,
    FirstName nvarchar(50) NOT NULL,
    LastName nvarchar(50) NOT NULL,
    Email nvarchar(160) NOT NULL,
    RegionCode char(2) NOT NULL,
    LoyaltyTier nvarchar(20) NOT NULL CONSTRAINT DF_Customers_LoyaltyTier DEFAULT (N'Standard'),
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Customers_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Customers_Email UNIQUE (Email)
);
GO

CREATE TABLE dbo.Products
(
    ProductId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
    Sku nvarchar(32) NOT NULL,
    ProductName nvarchar(120) NOT NULL,
    Category nvarchar(60) NOT NULL,
    UnitPrice decimal(12,2) NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Products_IsActive DEFAULT (1),
    CONSTRAINT UQ_Products_Sku UNIQUE (Sku)
);
GO

CREATE TABLE dbo.Inventory
(
    ProductId int NOT NULL,
    WarehouseCode nvarchar(20) NOT NULL,
    QuantityOnHand int NOT NULL,
    ReorderPoint int NOT NULL,
    LastCountedAt datetime2(0) NOT NULL,
    CONSTRAINT PK_Inventory PRIMARY KEY (ProductId, WarehouseCode),
    CONSTRAINT FK_Inventory_Products FOREIGN KEY (ProductId)
        REFERENCES dbo.Products (ProductId)
);
GO

CREATE TABLE dbo.Orders
(
    OrderId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId int NOT NULL,
    OrderDate datetime2(0) NOT NULL,
    OrderStatus nvarchar(20) NOT NULL,
    Channel nvarchar(20) NOT NULL,
    ShipRegionCode char(2) NOT NULL,
    OrderTotal decimal(14,2) NOT NULL CONSTRAINT DF_Orders_OrderTotal DEFAULT (0),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers (CustomerId)
);
GO

CREATE TABLE dbo.OrderLines
(
    OrderLineId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderLines PRIMARY KEY,
    OrderId bigint NOT NULL,
    ProductId int NOT NULL,
    Quantity int NOT NULL,
    UnitPrice decimal(12,2) NOT NULL,
    DiscountPct decimal(5,4) NOT NULL CONSTRAINT DF_OrderLines_DiscountPct DEFAULT (0),
    LineTotal AS (CONVERT(decimal(14,2), Quantity * UnitPrice * (1 - DiscountPct))) PERSISTED,
    CONSTRAINT FK_OrderLines_Orders FOREIGN KEY (OrderId)
        REFERENCES dbo.Orders (OrderId),
    CONSTRAINT FK_OrderLines_Products FOREIGN KEY (ProductId)
        REFERENCES dbo.Products (ProductId),
    CONSTRAINT CK_OrderLines_Quantity CHECK (Quantity > 0)
);
GO

CREATE TABLE dbo.EtlAudit
(
    EtlAuditId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_EtlAudit PRIMARY KEY,
    PackageName nvarchar(128) NOT NULL,
    StartedAt datetime2(0) NOT NULL,
    CompletedAt datetime2(0) NULL,
    RowsProcessed int NOT NULL CONSTRAINT DF_EtlAudit_RowsProcessed DEFAULT (0),
    Status nvarchar(20) NOT NULL
);
GO

CREATE INDEX IX_Customers_RegionCode ON dbo.Customers (RegionCode);
CREATE INDEX IX_Orders_CustomerDate ON dbo.Orders (CustomerId, OrderDate DESC) INCLUDE (OrderTotal, OrderStatus);
CREATE INDEX IX_Orders_DateStatus ON dbo.Orders (OrderDate, OrderStatus);
CREATE INDEX IX_OrderLines_Product ON dbo.OrderLines (ProductId) INCLUDE (Quantity, LineTotal);
CREATE INDEX IX_Inventory_Reorder ON dbo.Inventory (WarehouseCode, QuantityOnHand, ReorderPoint);
GO

CREATE OR ALTER VIEW dbo.vwSalesByRegion
AS
SELECT
    c.RegionCode,
    COUNT_BIG(*) AS OrderCount,
    SUM(o.OrderTotal) AS SalesAmount,
    MAX(o.OrderDate) AS LastOrderDate
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c
    ON c.CustomerId = o.CustomerId
GROUP BY c.RegionCode;
GO

/*
    Intentional cross-database query for assessment labs.
    Azure SQL Database does not support this three-part-name pattern between
    user databases without redesign; Azure SQL Managed Instance preserves it.
*/
CREATE OR ALTER VIEW dbo.vwCustomerTaxProfile
AS
SELECT
    c.CustomerId,
    c.CustomerNumber,
    c.Email,
    c.RegionCode,
    r.RegionName,
    r.SalesRegion,
    tr.TaxCode,
    tr.Rate
FROM dbo.Customers AS c
INNER JOIN TailwindRef.dbo.Regions AS r
    ON r.RegionCode = c.RegionCode
INNER JOIN TailwindRef.dbo.TaxRates AS tr
    ON tr.RegionCode = c.RegionCode
WHERE tr.EffectiveFrom =
(
    SELECT MAX(tr2.EffectiveFrom)
    FROM TailwindRef.dbo.TaxRates AS tr2
    WHERE tr2.RegionCode = tr.RegionCode
      AND tr2.TaxCode = tr.TaxCode
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerOrderSummary
    @CustomerId int,
    @FromDate datetime2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.CustomerId,
        c.CustomerNumber,
        c.FirstName,
        c.LastName,
        COUNT(o.OrderId) AS OrderCount,
        COALESCE(SUM(o.OrderTotal), 0) AS TotalSpend,
        MAX(o.OrderDate) AS LastOrderDate
    FROM dbo.Customers AS c
    LEFT JOIN dbo.Orders AS o
        ON o.CustomerId = c.CustomerId
       AND (@FromDate IS NULL OR o.OrderDate >= @FromDate)
    WHERE c.CustomerId = @CustomerId
    GROUP BY c.CustomerId, c.CustomerNumber, c.FirstName, c.LastName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RunNightlyEtl
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @auditId bigint;

    INSERT dbo.EtlAudit (PackageName, StartedAt, Status)
    VALUES (N'TailwindNightlyEtl.dtsx', SYSUTCDATETIME(), N'Running');

    SET @auditId = SCOPE_IDENTITY();

    UPDATE o
       SET OrderTotal = totals.OrderTotal
    FROM dbo.Orders AS o
    INNER JOIN
    (
        SELECT OrderId, SUM(LineTotal) AS OrderTotal
        FROM dbo.OrderLines
        GROUP BY OrderId
    ) AS totals
        ON totals.OrderId = o.OrderId;

    UPDATE dbo.EtlAudit
       SET CompletedAt = SYSUTCDATETIME(),
           RowsProcessed = @@ROWCOUNT,
           Status = N'Succeeded'
     WHERE EtlAuditId = @auditId;
END;
GO
