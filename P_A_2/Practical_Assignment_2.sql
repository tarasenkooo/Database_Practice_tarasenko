
CREATE DATABASE IF NOT EXISTS opt_db;
USE opt_db;

CREATE TABLE IF NOT EXISTS opt_clients (
    id CHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    surname VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    address TEXT NOT NULL,
    status ENUM('active', 'inactive') NOT NULL
);

CREATE TABLE IF NOT EXISTS opt_products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    product_category ENUM('Category1', 'Category2', 'Category3', 'Category4', 'Category5') NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS opt_orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    order_date DATE NOT NULL,
    client_id CHAR(36),
    product_id INT,
    FOREIGN KEY (client_id) REFERENCES opt_clients(id),
    FOREIGN KEY (product_id) REFERENCES opt_products(product_id)
);





-- Non-optimized example 1
SELECT c.name, c.surname, p.product_name, o.order_date
FROM opt_clients c
JOIN opt_orders o ON c.id = o.client_id
JOIN opt_products p ON o.product_id = p.product_id
WHERE c.status = 'active'
AND p.product_category = 'Category1'
ORDER BY o.order_date DESC
LIMIT 10;


EXPLAIN ANALYZE SELECT c.name, c.surname, p.product_name, o.order_date
FROM opt_clients c
JOIN opt_orders o ON c.id = o.client_id
JOIN opt_products p ON o.product_id = p.product_id
WHERE c.status = 'active'
AND p.product_category = 'Category1'
ORDER BY o.order_date DESC
LIMIT 10;

EXPLAIN ANALYZE
SELECT c.name, c.surname, p.product_name, o.order_date
FROM opt_clients c
IGNORE INDEX (idx_client_status)
JOIN opt_orders o IGNORE INDEX (idx_order_client_id, idx_order_product_id, idx_order_date)
ON c.id = o.client_id
JOIN opt_products p IGNORE INDEX (idx_product_category)
ON o.product_id = p.product_id
WHERE c.status = 'active'
AND p.product_category = 'Category1'
ORDER BY o.order_date DESC
LIMIT 10;


/*
 -- -> Limit: 10 row(s)  (actual time=2332..2332 rows=10 loops=1)
    -> Sort: o.order_date DESC, limit input to 10 row(s) per chunk  (actual time=2332..2332 rows=10 loops=1)
        -> Stream results  (cost=199843 rows=99568) (actual time=13.4..2324 rows=99363 loops=1)
            -> Nested loop inner join  (cost=199843 rows=99568) (actual time=13.4..2304 rows=99363 loops=1)
                -> Nested loop inner join  (cost=115364 rows=199136) (actual time=13.4..1818 rows=199026 loops=1)
                    -> Filter: (p.product_category = 'Category1')  (cost=105 rows=200) (actual time=0.401..1.93 rows=199 loops=1)
                        -> Table scan on p  (cost=105 rows=1000) (actual time=0.381..1.79 rows=1000 loops=1)
                    -> Filter: (o.client_id is not null)  (cost=477 rows=996) (actual time=0.857..9.09 rows=1000 loops=199)
                        -> Index lookup on o using product_id (product_id=p.product_id)  (cost=477 rows=996) (actual time=0.856..9.05 rows=1000 loops=199)
                -> Filter: (c.`status` = 'active')  (cost=0.324 rows=0.5) (actual time=0.00234..0.00237 rows=0.499 loops=199026)
                    -> Single-row index lookup on c using PRIMARY (id=o.client_id)  (cost=0.324 rows=1) (actual time=0.00222..0.00224 rows=1 loops=199026)
                     */

/*
 * -> Limit: 10 row(s)  (actual time=1226..1226 rows=10 loops=1)
    -> Sort: o.order_date DESC, limit input to 10 row(s) per chunk  (actual time=1226..1226 rows=10 loops=1)
        -> Stream results  (cost=148054 rows=105731) (actual time=65.7..1217 rows=99363 loops=1)
            -> Nested loop inner join  (cost=148054 rows=105731) (actual time=65.3..1197 rows=99363 loops=1)
                -> Nested loop inner join  (cost=74042 rows=211462) (actual time=64.8..739 rows=199026 loops=1)
                    -> Index lookup on p using idx_product_category (product_category='Category1'), with index condition: (p.product_category = 'Category1')  (cost=30.4 rows=199) (actual time=4.47..4.62 rows=199 loops=1)
                    -> Filter: (o.client_id is not null)  (cost=266 rows=1063) (actual time=0.6..3.65 rows=1000 loops=199)
                        -> Index lookup on o using idx_order_product_id (product_id=p.product_id)  (cost=266 rows=1063) (actual time=0.599..3.62 rows=1000 loops=199)
                -> Filter: (c.`status` = 'active')  (cost=0.25 rows=0.5) (actual time=0.0022..0.00223 rows=0.499 loops=199026)
                    -> Single-row index lookup on c using PRIMARY (id=o.client_id)  (cost=0.25 rows=1) (actual time=0.00208..0.0021 rows=1 loops=199026)

 */

-- Non-optimized example 2

SELECT 
    (SELECT name FROM opt_clients c WHERE c.id = o.client_id AND c.status = 'active') AS name, 
    (SELECT surname FROM opt_clients c WHERE c.id = o.client_id AND c.status = 'active') AS surname, 
    (SELECT product_name FROM opt_products p WHERE p.product_id = o.product_id AND p.product_category = 'Category1') AS product_name, 
    o.order_date
FROM 
    opt_orders o
WHERE 
    EXISTS (SELECT * FROM opt_clients c WHERE c.id = o.client_id AND c.status = 'active')
    AND EXISTS (SELECT * FROM opt_products p WHERE p.product_id = o.product_id AND p.product_category = 'Category1')
ORDER BY 
    o.order_date DESC
LIMIT 10;



EXPLAIN ANALYZE SELECT 
    (SELECT name FROM opt_clients c WHERE c.id = o.client_id AND c.status = 'active') AS name, 
    (SELECT surname FROM opt_clients c WHERE c.id = o.client_id AND c.status = 'active') AS surname, 
    (SELECT product_name FROM opt_products p WHERE p.product_id = o.product_id AND p.product_category = 'Category1') AS product_name, 
    o.order_date
FROM 
    opt_orders o
WHERE 
    EXISTS (SELECT * FROM opt_clients c WHERE c.id = o.client_id AND c.status = 'active')
    AND EXISTS (SELECT * FROM opt_products p WHERE p.product_id = o.product_id AND p.product_category = 'Category1')
ORDER BY 
    o.order_date DESC
LIMIT 10;

/*
 * -> Limit: 10 row(s)  (actual time=1166..1166 rows=10 loops=1)
    -> Sort: o.order_date DESC, limit input to 10 row(s) per chunk  (actual time=1165..1165 rows=10 loops=1)
        -> Stream results  (cost=148045 rows=105731) (actual time=10.5..1157 rows=99363 loops=1)
            -> Nested loop inner join  (cost=148045 rows=105731) (actual time=9.92..808 rows=99363 loops=1)
                -> Nested loop inner join  (cost=74033 rows=211462) (actual time=9.59..431 rows=199026 loops=1)
                    -> Filter: (p.product_category = 'Category1')  (cost=21 rows=199) (actual time=0.916..1 rows=199 loops=1)
                        -> Covering index lookup on p using idx_product_category (product_category='Category1')  (cost=21 rows=199) (actual time=0.9..0.955 rows=199 loops=1)
                    -> Filter: (o.client_id is not null)  (cost=266 rows=1063) (actual time=0.226..2.12 rows=1000 loops=199)
                        -> Index lookup on o using idx_order_product_id (product_id=p.product_id)  (cost=266 rows=1063) (actual time=0.226..2.09 rows=1000 loops=199)
                -> Filter: (c.`status` = 'active')  (cost=0.25 rows=0.5) (actual time=0.0018..0.00182 rows=0.499 loops=199026)
                    -> Single-row index lookup on c using PRIMARY (id=o.client_id)  (cost=0.25 rows=1) (actual time=0.00168..0.00169 rows=1 loops=199026)
-> Select #2 (subquery in projection; dependent)
    -> Filter: (c.`status` = 'active')  (cost=0.3 rows=0.5) (actual time=0.00112..0.00117 rows=1 loops=99363)
        -> Single-row index lookup on c using PRIMARY (id=o.client_id)  (cost=0.3 rows=1) (actual time=0.00101..0.00103 rows=1 loops=99363)
-> Select #3 (subquery in projection; dependent)
    -> Filter: (c.`status` = 'active')  (cost=0.3 rows=0.5) (actual time=0.0011..0.00116 rows=1 loops=99363)
        -> Single-row index lookup on c using PRIMARY (id=o.client_id)  (cost=0.3 rows=1) (actual time=994e-6..0.00101 rows=1 loops=99363)
-> Select #4 (subquery in projection; dependent)
    -> Filter: (p.product_category = 'Category1')  (cost=0.27 rows=0.199) (actual time=562e-6..615e-6 rows=1 loops=99363)
        -> Single-row index lookup on p using PRIMARY (product_id=o.product_id)  (cost=0.27 rows=1) (actual time=424e-6..443e-6 rows=1 loops=99363)

 */

-- Optimized example

CREATE INDEX idx_client_status ON opt_clients(status);
CREATE INDEX idx_product_category ON opt_products(product_category);
CREATE INDEX idx_order_client_id ON opt_orders(client_id);
CREATE INDEX idx_order_product_id ON opt_orders(product_id);
CREATE INDEX idx_order_date ON opt_orders(order_date);

  WITH ActiveClients AS (
    SELECT id, name, surname
    FROM opt_clients
    WHERE status = 'active'
),
FilteredProducts AS (
    SELECT product_id, product_name
    FROM opt_products
    WHERE product_category = 'Category1'
)
SELECT c.name, c.surname, p.product_name, o.order_date
FROM ActiveClients c
JOIN opt_orders o ON c.id = o.client_id
JOIN FilteredProducts p ON o.product_id = p.product_id
ORDER BY o.order_date DESC
LIMIT 10;




EXPLAIN ANALYZE WITH ActiveClients AS (
    SELECT id, name, surname
    FROM opt_clients
    WHERE status = 'active'
),
FilteredProducts AS (
    SELECT product_id, product_name
    FROM opt_products
    WHERE product_category = 'Category1'
)
SELECT c.name, c.surname, p.product_name, o.order_date
FROM ActiveClients c
JOIN opt_orders o ON c.id = o.client_id
JOIN FilteredProducts p ON o.product_id = p.product_id
ORDER BY o.order_date DESC
LIMIT 10;

/*
 * -> Limit: 10 row(s)  (actual time=878..878 rows=10 loops=1)
    -> Sort: o.order_date DESC, limit input to 10 row(s) per chunk  (actual time=878..878 rows=10 loops=1)
        -> Stream results  (cost=148054 rows=105731) (actual time=12.2..869 rows=99363 loops=1)
            -> Nested loop inner join  (cost=148054 rows=105731) (actual time=11.7..846 rows=99363 loops=1)
                -> Nested loop inner join  (cost=74042 rows=211462) (actual time=11.7..443 rows=199026 loops=1)
                    -> Index lookup on opt_products using idx_product_category (product_category='Category1'), with index condition: (opt_products.product_category = 'Category1')  (cost=30.4 rows=199) (actual time=1.81..1.95 rows=199 loops=1)
                    -> Filter: (o.client_id is not null)  (cost=266 rows=1063) (actual time=0.254..2.18 rows=1000 loops=199)
                        -> Index lookup on o using idx_order_product_id (product_id=opt_products.product_id)  (cost=266 rows=1063) (actual time=0.254..2.15 rows=1000 loops=199)
                -> Filter: (opt_clients.`status` = 'active')  (cost=0.25 rows=0.5) (actual time=0.00193..0.00195 rows=0.499 loops=199026)
                    -> Single-row index lookup on opt_clients using PRIMARY (id=o.client_id)  (cost=0.25 rows=1) (actual time=0.0018..0.00182 rows=1 loops=199026)

 */


use performance_schema;
show tables;

SELECT (100 * SUM_TIMER_WAIT / sum(SUM_TIMER_WAIT)
OVER ()) percent,
SUM_TIMER_WAIT AS total,
COUNT_STAR AS calls,
AVG_TIMER_WAIT AS mean,
substring(DIGEST_TEXT, 1, 200)
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

