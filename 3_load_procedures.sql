USE ecom_dwh;
GO

-- парсит вес из описания товара, возвращает граммы/мл
-- поддерживает форматы: «xxx г.», «x кг.», «xxx мл.», «x л.»
CREATE OR ALTER FUNCTION dbo.fn_extract_weight(@desc NVARCHAR(500))
RETURNS DECIMAL(8,3)
AS
BEGIN
    DECLARE @pos INT;
    DECLARE @str NVARCHAR(20);

    SET @pos = PATINDEX('%[0-9]% г.%',  @desc);
    IF @pos > 0 BEGIN SET @str = SUBSTRING(@desc, @pos, 6); RETURN CAST(LEFT(@str, PATINDEX('%[^0-9]%', @str) - 1) AS DECIMAL(8,3)); END

    SET @pos = PATINDEX('%[0-9]% кг.%', @desc);
    IF @pos > 0 BEGIN SET @str = SUBSTRING(@desc, @pos, 6); RETURN CAST(LEFT(@str, PATINDEX('%[^0-9]%', @str) - 1) AS DECIMAL(8,3)) * 1000; END

    SET @pos = PATINDEX('%[0-9]% мл.%', @desc);
    IF @pos > 0 BEGIN SET @str = SUBSTRING(@desc, @pos, 6); RETURN CAST(LEFT(@str, PATINDEX('%[^0-9]%', @str) - 1) AS DECIMAL(8,3)); END

    SET @pos = PATINDEX('%[0-9]% л.%',  @desc);
    IF @pos > 0 BEGIN SET @str = SUBSTRING(@desc, @pos, 6); RETURN CAST(LEFT(@str, PATINDEX('%[^0-9]%', @str) - 1) AS DECIMAL(8,3)) * 1000; END

    RETURN NULL;
END;
GO

-- клиенты
CREATE OR ALTER PROCEDURE dbo.usp_load_customers
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.customer AS tgt
    USING dbo.klienti  AS src ON tgt.customer_id = src.customer_id
    WHEN MATCHED AND (tgt.phone_number <> src.phone_number OR tgt.city <> src.city)
        THEN UPDATE SET
            tgt.subname          = src.subname,
            tgt.name             = src.name,
            tgt.phone_number     = src.phone_number,
            tgt.city             = src.city,
            tgt.Registrated_date = src.Registrated_date,
            tgt.dwh_updated_at   = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (customer_id, subname, name, phone_number, city, Registrated_date)
             VALUES (src.customer_id, src.subname, src.name, src.phone_number, src.city, src.Registrated_date);
END;
GO

--товары (парсинг веса из описания)
CREATE OR ALTER PROCEDURE dbo.usp_load_products
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.products AS tgt
    USING dbo.tovari   AS src ON tgt.product_id = src.product_id
    WHEN MATCHED AND (tgt.price <> src.Price OR ISNULL(tgt.Description,'') <> ISNULL(src.Description,''))
        THEN UPDATE SET
            tgt.name           = src.name,
            tgt.Description    = src.Description,
            tgt.price          = src.Price,
            tgt.weight         = dbo.fn_extract_weight(src.Description),
            tgt.is_deleted     = 0,
            tgt.dwh_updated_at = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (product_id, name, Description, price, weight, created_at)
             VALUES (src.product_id, src.name, src.Description, src.Price, dbo.fn_extract_weight(src.Description), src.created_at)
    WHEN NOT MATCHED BY SOURCE AND tgt.is_deleted = 0
        THEN UPDATE SET tgt.is_deleted = 1, tgt.dwh_updated_at = SYSUTCDATETIME();
END;
GO

-- заказы (инкремент по updated_at — watermark)
CREATE OR ALTER PROCEDURE dbo.usp_load_orders
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @last_load DATETIME2 = (SELECT ISNULL(MAX(updated_at), '1900-01-01') FROM dbo.orders);

    MERGE dbo.orders AS tgt
    USING (
        SELECT z.order_id, c.dwh_customer_id, p.dwh_product_id,
               z.quantity, z.order_dt, z.amount, z.status, z.created_at, z.updated_at
        FROM       dbo.zakazi   AS z
        JOIN       dbo.customer AS c ON c.customer_id = z.customer_id
        JOIN       dbo.products AS p ON p.product_id  = z.product_id
        WHERE z.updated_at >= @last_load
    ) AS src ON tgt.order_id = src.order_id
    WHEN MATCHED AND (tgt.status <> src.status OR tgt.amount <> src.amount)
        THEN UPDATE SET
            tgt.status         = src.status,
            tgt.amount         = src.amount,
            tgt.updated_at     = src.updated_at,
            tgt.dwh_updated_at = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (order_id, dwh_customer_id, dwh_product_id, quantity, order_dt, amount, status, created_at, updated_at)
             VALUES (src.order_id, src.dwh_customer_id, src.dwh_product_id, src.quantity, src.order_dt, src.amount, src.status, src.created_at, src.updated_at);
END;
GO

-- orders зависит от customer и products
CREATE OR ALTER PROCEDURE dbo.usp_run_dwh_load
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.usp_load_customers;
    EXEC dbo.usp_load_products;
    EXEC dbo.usp_load_orders;
END;
GO
