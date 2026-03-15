-- витрина топ-5 товаров по городам
-- Витрина пересчитывается полностью
USE ecom_dwh;
GO

CREATE OR ALTER PROCEDURE dbo.usp_build_dm_top_products
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dbo.dm_top_products_by_city;

    INSERT INTO dbo.dm_top_products_by_city
        (city, dwh_product_id, product_name, total_quantity, total_amount, city_rank, report_dt)
    SELECT city, dwh_product_id, product_name, total_quantity, total_amount,
           city_rank, CAST(SYSUTCDATETIME() AS DATE)
    FROM (
        SELECT
            c.city,
            p.dwh_product_id,
            p.name              AS product_name,
            SUM(o.quantity)     AS total_quantity,
            SUM(o.amount)       AS total_amount,
            DENSE_RANK() OVER (PARTITION BY c.city ORDER BY SUM(o.quantity) DESC) AS city_rank
        FROM      dbo.orders   AS o
        JOIN      dbo.customer AS c ON c.dwh_customer_id = o.dwh_customer_id
        JOIN      dbo.products AS p ON p.dwh_product_id  = o.dwh_product_id
        WHERE     o.status IN ('PAID', 'SHIPPED') AND p.is_deleted = 0
        GROUP BY  c.city, p.dwh_product_id, p.name
    ) AS ranked
    WHERE city_rank <= 5;
END;
GO
