-- ============================================================================
-- Bean & Roast Co. — specialty coffee shop + online store
-- Database schema (SQLite-compatible)
--
-- A realistic relational design for a small business that sells drinks
-- in-store and beans/equipment online. Run with:
--   sqlite3 shop.db < schema.sql
--   sqlite3 shop.db < seed.sql
-- ============================================================================

PRAGMA foreign_keys = ON;

-- Product categories (drinks, retail beans, brewing equipment, merch)
CREATE TABLE IF NOT EXISTS categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,
    description TEXT    NOT NULL DEFAULT '',
    is_online   INTEGER NOT NULL DEFAULT 1 CHECK (is_online IN (0, 1))
);

-- Suppliers of coffee beans and equipment
CREATE TABLE IF NOT EXISTS suppliers (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT    NOT NULL UNIQUE,
    contact_name  TEXT    NOT NULL,
    email         TEXT    NOT NULL CHECK (email LIKE '%@%'),
    phone         TEXT    NOT NULL DEFAULT '',
    country       TEXT    NOT NULL DEFAULT '',
    lead_days     INTEGER NOT NULL DEFAULT 7 CHECK (lead_days >= 0),
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
);

-- Everything the shop sells, in-store and online
CREATE TABLE IF NOT EXISTS products (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    sku         TEXT    NOT NULL UNIQUE CHECK (length(sku) >= 3),
    name        TEXT    NOT NULL,
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    supplier_id INTEGER     REFERENCES suppliers(id) ON DELETE SET NULL,
    price_cents INTEGER NOT NULL CHECK (price_cents > 0),        -- sale price
    cost_cents  INTEGER NOT NULL CHECK (cost_cents >= 0),        -- landed cost
    sold_online INTEGER NOT NULL DEFAULT 1 CHECK (sold_online IN (0, 1)),
    sold_inshop INTEGER NOT NULL DEFAULT 1 CHECK (sold_inshop IN (0, 1)),
    is_active   INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    CHECK (cost_cents < price_cents)
);

-- Customers: walk-ins with loyalty cards + online accounts
CREATE TABLE IF NOT EXISTS customers (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name     TEXT    NOT NULL CHECK (length(first_name) >= 1),
    last_name      TEXT    NOT NULL CHECK (length(last_name)  >= 1),
    email          TEXT        UNIQUE CHECK (email IS NULL OR email LIKE '%@%'),
    phone          TEXT    NOT NULL DEFAULT '',
    city           TEXT    NOT NULL DEFAULT '',
    loyalty_member INTEGER NOT NULL DEFAULT 0 CHECK (loyalty_member IN (0, 1)),
    created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- A customer order (in-store or online), one row per checkout
CREATE TABLE IF NOT EXISTS orders (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id  INTEGER REFERENCES customers(id) ON DELETE SET NULL,
    channel      TEXT    NOT NULL CHECK (channel IN ('in-store', 'online')),
    status       TEXT    NOT NULL DEFAULT 'completed'
                        CHECK (status IN ('completed', 'refunded', 'pending')),
    placed_at    TEXT    NOT NULL DEFAULT (datetime('now')),
    discount_cents INTEGER NOT NULL DEFAULT 0 CHECK (discount_cents >= 0)
);

-- Line items: what was bought on each order
CREATE TABLE IF NOT EXISTS order_items (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id    INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    qty         INTEGER NOT NULL CHECK (qty > 0),
    price_cents INTEGER NOT NULL CHECK (price_cents > 0),   -- price at sale time
    UNIQUE (order_id, product_id)
);

-- Stock on hand for every product, updated by sales and restocks
CREATE TABLE IF NOT EXISTS inventory (
    product_id     INTEGER PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
    qty_on_hand    INTEGER NOT NULL DEFAULT 0 CHECK (qty_on_hand >= 0),
    reorder_level  INTEGER NOT NULL DEFAULT 10 CHECK (reorder_level >= 0),
    last_restocked TEXT    NOT NULL DEFAULT (date('now'))
);

-- Business expenses (rent, payroll, beans restock, ads, ...)
CREATE TABLE IF NOT EXISTS expenses (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    category     TEXT    NOT NULL CHECK (category IN
                       ('rent', 'payroll', 'inventory', 'utilities',
                        'marketing', 'equipment', 'other')),
    description  TEXT    NOT NULL,
    amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
    spent_on     TEXT    NOT NULL DEFAULT (date('now'))
);

-- Indexes for the queries a small business actually runs
CREATE INDEX IF NOT EXISTS idx_orders_placed_at   ON orders(placed_at);
CREATE INDEX IF NOT EXISTS idx_orders_customer    ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order  ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_products_category  ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_expenses_spent_on  ON expenses(spent_on);
CREATE INDEX IF NOT EXISTS idx_customers_email    ON customers(email);
