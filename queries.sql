-- ============================================================================
-- Bean & Roast Co. — reporting queries
-- Run any of these against the seeded database:
--   sqlite3 shop.db < queries.sql
-- Prices are stored in cents; each query converts to dollars for readability.
-- ============================================================================

-- Q1. Daily revenue for the last 30 days
-- "Are we trending up or down this month?" — run every morning.
SELECT date(placed_at) AS day,
       printf('$%.2f', SUM(oi.qty * oi.price_cents - o.discount_cents) / 100.0) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'completed'
  AND date(placed_at) >= date('now', '-30 days')
GROUP BY day
ORDER BY day;

-- Q2. Top 5 products by revenue
-- "What should we promote, keep in stock, and never run out of?"
SELECT p.name,
       printf('$%.2f', SUM(oi.qty * oi.price_cents) / 100.0) AS revenue,
       SUM(oi.qty) AS units_sold
FROM order_items oi
JOIN products p ON p.id = oi.product_id
JOIN orders o   ON o.id = oi.order_id
WHERE o.status = 'completed'
GROUP BY p.id, p.name
ORDER BY SUM(oi.qty * oi.price_cents) DESC
LIMIT 5;

-- Q3. Low-stock alert
-- "What needs reordering this week before we sell out?"
SELECT p.sku,
       p.name,
       i.qty_on_hand,
       i.reorder_level,
       s.name AS supplier,
       s.lead_days AS supplier_lead_days
FROM inventory i
JOIN products p  ON p.id = i.product_id
LEFT JOIN suppliers s ON s.id = p.supplier_id
WHERE i.qty_on_hand <= i.reorder_level
ORDER BY i.qty_on_hand - i.reorder_level;

-- Q4. Profit by category (revenue minus product cost)
-- "Which part of the business actually makes money?"
SELECT c.name AS category,
       printf('$%.2f', SUM(oi.qty * oi.price_cents) / 100.0) AS revenue,
       printf('$%.2f', SUM(oi.qty * p.cost_cents)   / 100.0) AS cost,
       printf('$%.2f', SUM(oi.qty * (oi.price_cents - p.cost_cents)) / 100.0) AS gross_profit,
       printf('%.1f%%', 100.0 * SUM(oi.qty * (oi.price_cents - p.cost_cents))
                      / SUM(oi.qty * oi.price_cents)) AS margin
FROM order_items oi
JOIN products p   ON p.id = oi.product_id
JOIN categories c ON c.id = p.category_id
JOIN orders o     ON o.id = oi.order_id
WHERE o.status = 'completed'
GROUP BY c.id, c.name
ORDER BY SUM(oi.qty * (oi.price_cents - p.cost_cents)) DESC;

-- Q5. Repeat-customer rate
-- "Are people coming back, or are we always hunting for new customers?"
SELECT printf('%.1f%%', 100.0 * COUNT(*) /
       (SELECT COUNT(*) FROM customers)) AS repeat_customer_rate,
       COUNT(*) AS repeat_customers,
       (SELECT COUNT(*) FROM customers) AS total_customers
FROM (
    SELECT customer_id
    FROM orders
    WHERE status = 'completed' AND customer_id IS NOT NULL
    GROUP BY customer_id
    HAVING COUNT(*) >= 2
);

-- Q6. Slowest-moving products
-- "What's gathering dust? Mark it down, bundle it, or stop ordering it."
SELECT p.sku,
       p.name,
       COALESCE(SUM(oi.qty), 0) AS units_sold,
       i.qty_on_hand
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o       ON o.id = oi.order_id AND o.status = 'completed'
LEFT JOIN inventory i    ON i.product_id = p.id
WHERE p.is_active = 1
GROUP BY p.id, p.sku, p.name, i.qty_on_hand
ORDER BY units_sold, i.qty_on_hand DESC;

-- Q7. Monthly revenue vs. expenses
-- "After everything is paid, what did each month actually earn?"
WITH revenue AS (
    SELECT strftime('%Y-%m', placed_at) AS month,
           SUM(oi.qty * oi.price_cents - o.discount_cents) / 100.0 AS total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.status = 'completed'
    GROUP BY month
),
costs AS (
    SELECT strftime('%Y-%m', spent_on) AS month,
           SUM(amount_cents) / 100.0 AS total
    FROM expenses
    GROUP BY month
)
SELECT r.month,
       printf('$%.2f', r.total) AS revenue,
       printf('$%.2f', COALESCE(c.total, 0)) AS expenses,
       printf('$%.2f', r.total - COALESCE(c.total, 0)) AS net
FROM revenue r
LEFT JOIN costs c ON c.month = r.month
ORDER BY r.month;

-- Q8. Best customers by lifetime value
-- "Who are our VIPs? These are the people who deserve the loyalty perks."
SELECT c.first_name || ' ' || c.last_name AS customer,
       c.city,
       COUNT(DISTINCT o.id) AS orders,
       printf('$%.2f', SUM(oi.qty * oi.price_cents - o.discount_cents) / 100.0)
           AS lifetime_value
FROM customers c
JOIN orders o      ON o.customer_id = c.id AND o.status = 'completed'
JOIN order_items oi ON oi.order_id = o.id
GROUP BY c.id
ORDER BY SUM(oi.qty * oi.price_cents - o.discount_cents) DESC
LIMIT 10;

-- Q9. Busiest hours of the day
-- "When should we schedule extra staff — and when can we run lean?"
SELECT strftime('%H:00', placed_at) AS hour,
       COUNT(*) AS orders,
       printf('$%.2f', SUM(oi.qty * oi.price_cents) / 100.0) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'completed' AND o.channel = 'in-store'
GROUP BY hour
ORDER BY orders DESC;

-- Q10. Online vs. in-store revenue split
-- "Is the webshop pulling its weight next to the physical counter?"
SELECT o.channel,
       COUNT(DISTINCT o.id) AS orders,
       printf('$%.2f', SUM(oi.qty * oi.price_cents) / 100.0) AS revenue,
       printf('%.1f%%', 100.0 * SUM(oi.qty * oi.price_cents) /
           (SELECT SUM(qty * price_cents)
            FROM order_items oi2 JOIN orders o2 ON o2.id = oi2.order_id
            WHERE o2.status = 'completed')) AS share_of_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY o.channel;
