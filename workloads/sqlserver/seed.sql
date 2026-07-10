SET NOCOUNT ON;
GO

USE TailwindRef;
GO

DELETE FROM dbo.TaxRates;
DELETE FROM dbo.Regions;

INSERT dbo.Regions (RegionCode, RegionName, SalesRegion, IsActive)
VALUES
    ('SE', N'Sweden', N'Nordics', 1),
    ('NO', N'Norway', N'Nordics', 1),
    ('DK', N'Denmark', N'Nordics', 1),
    ('FI', N'Finland', N'Nordics', 1),
    ('DE', N'Germany', N'DACH', 1),
    ('NL', N'Netherlands', N'Benelux', 1),
    ('GB', N'United Kingdom', N'UKI', 1),
    ('US', N'United States', N'North America', 1);

INSERT dbo.TaxRates (RegionCode, TaxCode, EffectiveFrom, Rate)
VALUES
    ('SE', N'STANDARD', '2025-01-01', 0.2500),
    ('NO', N'STANDARD', '2025-01-01', 0.2500),
    ('DK', N'STANDARD', '2025-01-01', 0.2500),
    ('FI', N'STANDARD', '2025-01-01', 0.2400),
    ('DE', N'STANDARD', '2025-01-01', 0.1900),
    ('NL', N'STANDARD', '2025-01-01', 0.2100),
    ('GB', N'STANDARD', '2025-01-01', 0.2000),
    ('US', N'STANDARD', '2025-01-01', 0.0825);
GO

USE TailwindOLTP;
GO

DELETE FROM dbo.OrderLines;
DELETE FROM dbo.Orders;
DELETE FROM dbo.Inventory;
DELETE FROM dbo.Products;
DELETE FROM dbo.EtlAudit;
DELETE FROM dbo.Customers;
DBCC CHECKIDENT ('dbo.Customers', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Products', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Orders', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.OrderLines', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.EtlAudit', RESEED, 0) WITH NO_INFOMSGS;
GO

DECLARE @i int = 1;
DECLARE @categories table (CategoryId int IDENTITY(1,1), CategoryName nvarchar(60));
INSERT @categories (CategoryName)
VALUES (N'Outdoor'), (N'Electronics'), (N'Home'), (N'Grocery'), (N'Apparel'), (N'Sports'), (N'Toys'), (N'Garden');

WHILE @i <= 64
BEGIN
    INSERT dbo.Products (Sku, ProductName, Category, UnitPrice, IsActive)
    SELECT
        CONCAT(N'TW-', RIGHT(CONCAT(N'0000', @i), 4)),
        CONCAT(N'Tailwind ', CategoryName, N' Item ', @i),
        CategoryName,
        CONVERT(decimal(12,2), 4.99 + ((@i * 7) % 180) + ((@i % 4) * 0.25)),
        1
    FROM @categories
    WHERE CategoryId = ((@i - 1) % 8) + 1;

    SET @i += 1;
END;

SET @i = 1;
WHILE @i <= 180
BEGIN
    INSERT dbo.Customers (FirstName, LastName, Email, RegionCode, LoyaltyTier, CreatedAt)
    VALUES
    (
        CONCAT(N'Guest', RIGHT(CONCAT(N'000', @i), 3)),
        CONCAT(N'Shopper', RIGHT(CONCAT(N'000', (@i * 17) % 997), 3)),
        CONCAT(N'customer', RIGHT(CONCAT(N'000', @i), 3), N'@synthetic.tailwindtraders.example'),
        CHOOSE((@i % 8) + 1, 'SE', 'NO', 'DK', 'FI', 'DE', 'NL', 'GB', 'US'),
        CHOOSE((@i % 4) + 1, N'Standard', N'Silver', N'Gold', N'Platinum'),
        DATEADD(day, -(@i % 365), SYSUTCDATETIME())
    );

    SET @i += 1;
END;

INSERT dbo.Inventory (ProductId, WarehouseCode, QuantityOnHand, ReorderPoint, LastCountedAt)
SELECT ProductId, v.WarehouseCode, 20 + ((ProductId * v.Seed) % 220), 15 + (ProductId % 25), DATEADD(day, -(ProductId % 30), SYSUTCDATETIME())
FROM dbo.Products
CROSS JOIN (VALUES (N'STO-01', 3), (N'AMS-01', 5), (N'DFW-01', 7)) AS v(WarehouseCode, Seed);

SET @i = 1;
WHILE @i <= 520
BEGIN
    INSERT dbo.Orders (CustomerId, OrderDate, OrderStatus, Channel, ShipRegionCode)
    SELECT
        ((@i - 1) % 180) + 1,
        DATEADD(hour, -(@i * 9), SYSUTCDATETIME()),
        CHOOSE((@i % 5) + 1, N'New', N'Paid', N'Packed', N'Shipped', N'Completed'),
        CHOOSE((@i % 4) + 1, N'Web', N'Mobile', N'Store', N'Marketplace'),
        RegionCode
    FROM dbo.Customers
    WHERE CustomerId = ((@i - 1) % 180) + 1;

    INSERT dbo.OrderLines (OrderId, ProductId, Quantity, UnitPrice, DiscountPct)
    SELECT
        SCOPE_IDENTITY(),
        p.ProductId,
        1 + ((@i + p.ProductId) % 4),
        p.UnitPrice,
        CASE WHEN @i % 9 = 0 THEN 0.1000 ELSE 0 END
    FROM dbo.Products AS p
    WHERE p.ProductId IN (((@i - 1) % 64) + 1, ((@i + 13) % 64) + 1, ((@i + 29) % 64) + 1);

    SET @i += 1;
END;

EXEC dbo.usp_RunNightlyEtl;
GO
