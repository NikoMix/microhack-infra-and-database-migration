\connect TailwindCatalog

TRUNCATE TABLE products, suppliers, categories RESTART IDENTITY CASCADE;

INSERT INTO categories (category_name)
VALUES
    ('Outdoor'),
    ('Electronics'),
    ('Home'),
    ('Grocery'),
    ('Apparel'),
    ('Sports'),
    ('Toys'),
    ('Garden'),
    ('Seasonal'),
    ('Clearance');

INSERT INTO suppliers (supplier_code, supplier_name, country_code, lead_time_days)
VALUES
    ('SUP-NOR-001', 'Nordic Wholesale Synthetic', 'SE', 7),
    ('SUP-EUR-002', 'Contoso Retail Supply', 'DE', 10),
    ('SUP-UKI-003', 'Fabrikam Distribution', 'GB', 12),
    ('SUP-USA-004', 'Adventure Works Fulfillment', 'US', 14),
    ('SUP-APL-005', 'Synthetic Orchard Goods', 'NL', 9),
    ('SUP-HOME-006', 'Tailwind Home Partners', 'DK', 8),
    ('SUP-TOY-007', 'Northwind Play Supply', 'FI', 11),
    ('SUP-GDN-008', 'Wingtip Garden Supply', 'NO', 13);

INSERT INTO products (sku, product_name, description, category_id, supplier_id, list_price, active, updated_at)
SELECT
    'CAT-' || lpad(gs::text, 5, '0') AS sku,
    'Tailwind Catalog Item ' || gs AS product_name,
    'Synthetic catalog item for migration assessment. Includes searchable color, size, and seasonal merchandising text ' || (gs % 17) AS description,
    ((gs - 1) % 10) + 1 AS category_id,
    ((gs - 1) % 8) + 1 AS supplier_id,
    round((9.99 + ((gs * 13) % 220))::numeric, 2) AS list_price,
    gs % 19 <> 0 AS active,
    now() - ((gs % 90) || ' days')::interval AS updated_at
FROM generate_series(1, 180) AS gs;
