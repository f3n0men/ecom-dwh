CREATE DATABASE ecom_dwh;
GO
USE ecom_dwh;
GO

-- source layer

CREATE TABLE dbo.klienti (
    customer_id      VARCHAR(10)  PRIMARY KEY,
    subname          NVARCHAR(60) NOT NULL,
    name             NVARCHAR(60) NOT NULL,
    phone_number     VARCHAR(20)  NOT NULL,
    city             NVARCHAR(60) NOT NULL,
    Registrated_date DATE         NOT NULL
);

CREATE TABLE dbo.tovari (
    product_id   VARCHAR(10)   PRIMARY KEY,
    name         NVARCHAR(100) NOT NULL,
    Description  NVARCHAR(500),
    Price        DECIMAL(10,2) NOT NULL,
    Weight       DECIMAL(8,3),
    created_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.zakazi (
    order_id     VARCHAR(20)   PRIMARY KEY,
    customer_id  VARCHAR(10)   NOT NULL,
    product_id   VARCHAR(10)   NOT NULL,
    quantity     INT           NOT NULL,
    order_dt     DATE          NOT NULL,
    amount       DECIMAL(12,2) NOT NULL,
    status       VARCHAR(20)   NOT NULL,
    created_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

-- dwh layer

CREATE TABLE dbo.customer (
    dwh_customer_id  INT IDENTITY PRIMARY KEY,
    customer_id      VARCHAR(10)  NOT NULL UNIQUE,
    subname          NVARCHAR(60) NOT NULL,
    name             NVARCHAR(60) NOT NULL,
    phone_number     VARCHAR(20)  NOT NULL,
    city             NVARCHAR(60) NOT NULL,
    Registrated_date DATE         NOT NULL,
    dwh_created_at   DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    dwh_updated_at   DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.products (
    dwh_product_id  INT IDENTITY  PRIMARY KEY,
    product_id      VARCHAR(10)   NOT NULL UNIQUE,
    name            NVARCHAR(100) NOT NULL,
    Description     NVARCHAR(500),
    price           DECIMAL(10,2) NOT NULL,
    weight          DECIMAL(8,3),
    created_at      DATETIME2     NOT NULL,
    is_deleted      BIT           NOT NULL DEFAULT 0,
    dwh_created_at  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    dwh_updated_at  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.orders (
    dwh_order_id     INT IDENTITY PRIMARY KEY,
    order_id         VARCHAR(20)   NOT NULL UNIQUE,
    dwh_customer_id  INT           NOT NULL REFERENCES dbo.customer(dwh_customer_id),
    dwh_product_id   INT           NOT NULL REFERENCES dbo.products(dwh_product_id),
    quantity         INT           NOT NULL,
    order_dt         DATE          NOT NULL,
    amount           DECIMAL(12,2) NOT NULL,
    status           VARCHAR(20)   NOT NULL,
    created_at       DATETIME2     NOT NULL,
    updated_at       DATETIME2     NOT NULL,
    dwh_created_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    dwh_updated_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

-- datamart layer

CREATE TABLE dbo.dm_top_products_by_city (
    id              INT IDENTITY PRIMARY KEY,
    city            NVARCHAR(60)  NOT NULL,
    dwh_product_id  INT           NOT NULL,
    product_name    NVARCHAR(100) NOT NULL,
    total_quantity  INT           NOT NULL,
    total_amount    DECIMAL(14,2) NOT NULL,
    city_rank       TINYINT       NOT NULL,
    report_dt       DATE          NOT NULL,
    dwh_updated_at  DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE INDEX IX_dm_top_city_rank      ON dbo.dm_top_products_by_city (city, city_rank);
CREATE INDEX IX_orders_status_product ON dbo.orders (status, dwh_product_id, dwh_customer_id) INCLUDE (quantity, amount);
GO