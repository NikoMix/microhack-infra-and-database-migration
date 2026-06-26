USE TailwindSessions;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Carts;
TRUNCATE TABLE Events;
TRUNCATE TABLE Sessions;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO Sessions (SessionId, CustomerNumber, StartedAt, LastSeenAt, UserAgent, DeviceType, RegionCode, IsAuthenticated)
WITH RECURSIVE seq(n) AS
(
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 260
)
SELECT
    UUID(),
    CASE WHEN n % 3 = 0 THEN CONCAT('C', LPAD(n, 6, '0')) ELSE NULL END,
    TIMESTAMPADD(MINUTE, -15 * n, UTC_TIMESTAMP()),
    TIMESTAMPADD(MINUTE, -15 * n, UTC_TIMESTAMP()),
    CONCAT('SyntheticBrowser/', 80 + (n % 12), ' TailwindLab'),
    ELT((n % 4) + 1, 'desktop', 'mobile', 'tablet', 'kiosk'),
    ELT((n % 8) + 1, 'SE', 'NO', 'DK', 'FI', 'DE', 'NL', 'GB', 'US'),
    n % 3 = 0
FROM seq;

INSERT INTO Events (SessionId, EventType, ProductSku, CreatedAt, Properties)
SELECT
    SessionId,
    'page_view',
    NULL,
    TIMESTAMPADD(SECOND, 20, StartedAt),
    JSON_OBJECT('path', '/home', 'synthetic', true)
FROM Sessions;

INSERT INTO Events (SessionId, EventType, ProductSku, CreatedAt, Properties)
SELECT
    SessionId,
    'product_view',
    CONCAT('TW-', LPAD((ROW_NUMBER() OVER (ORDER BY StartedAt) % 64) + 1, 4, '0')),
    TIMESTAMPADD(MINUTE, 2, StartedAt),
    JSON_OBJECT('recommendationSlot', ROW_NUMBER() OVER (ORDER BY StartedAt) % 5)
FROM Sessions
WHERE IsAuthenticated OR RegionCode IN ('SE', 'DE', 'US');

INSERT INTO Carts (SessionId, ProductSku, Quantity, AddedAt, UpdatedAt, IsCheckedOut)
SELECT
    SessionId,
    CONCAT('TW-', LPAD((ROW_NUMBER() OVER (ORDER BY StartedAt DESC) % 64) + 1, 4, '0')),
    1 + (ROW_NUMBER() OVER (ORDER BY StartedAt DESC) % 3),
    TIMESTAMPADD(MINUTE, 4, StartedAt),
    TIMESTAMPADD(MINUTE, 8, StartedAt),
    ROW_NUMBER() OVER (ORDER BY StartedAt DESC) % 5 = 0
FROM Sessions
WHERE IsAuthenticated OR DeviceType = 'mobile';

INSERT INTO Events (SessionId, EventType, ProductSku, CreatedAt, Properties)
SELECT
    c.SessionId,
    CASE WHEN c.IsCheckedOut THEN 'checkout' ELSE 'add_to_cart' END,
    c.ProductSku,
    c.UpdatedAt,
    JSON_OBJECT('quantity', c.Quantity, 'checkedOut', c.IsCheckedOut)
FROM Carts AS c;
