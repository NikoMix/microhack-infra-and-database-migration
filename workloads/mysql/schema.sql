CREATE DATABASE IF NOT EXISTS TailwindSessions;
USE TailwindSessions;

CREATE TABLE IF NOT EXISTS Sessions
(
    SessionId char(36) NOT NULL,
    CustomerNumber varchar(20) NULL,
    StartedAt datetime(0) NOT NULL,
    LastSeenAt datetime(0) NOT NULL,
    UserAgent varchar(255) NOT NULL,
    DeviceType varchar(30) NOT NULL,
    RegionCode char(2) NOT NULL,
    IsAuthenticated boolean NOT NULL DEFAULT false,
    PRIMARY KEY (SessionId),
    KEY IX_Sessions_LastSeenAt (LastSeenAt),
    KEY IX_Sessions_RegionDevice (RegionCode, DeviceType)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Events
(
    EventId bigint NOT NULL AUTO_INCREMENT,
    SessionId char(36) NOT NULL,
    EventType varchar(40) NOT NULL,
    ProductSku varchar(32) NULL,
    CreatedAt datetime(0) NOT NULL,
    Properties json NULL,
    PRIMARY KEY (EventId),
    KEY IX_Events_SessionCreated (SessionId, CreatedAt),
    KEY IX_Events_TypeCreated (EventType, CreatedAt),
    CONSTRAINT FK_Events_Sessions FOREIGN KEY (SessionId)
        REFERENCES Sessions (SessionId)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Carts
(
    CartId bigint NOT NULL AUTO_INCREMENT,
    SessionId char(36) NOT NULL,
    ProductSku varchar(32) NOT NULL,
    Quantity int NOT NULL,
    AddedAt datetime(0) NOT NULL,
    UpdatedAt datetime(0) NOT NULL,
    IsCheckedOut boolean NOT NULL DEFAULT false,
    PRIMARY KEY (CartId),
    KEY IX_Carts_Session (SessionId),
    KEY IX_Carts_Product (ProductSku),
    CONSTRAINT FK_Carts_Sessions FOREIGN KEY (SessionId)
        REFERENCES Sessions (SessionId)
        ON DELETE CASCADE,
    CONSTRAINT CK_Carts_Quantity CHECK (Quantity > 0)
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_events_update_session_last_seen;
DELIMITER //
CREATE TRIGGER trg_events_update_session_last_seen
AFTER INSERT ON Events
FOR EACH ROW
BEGIN
    UPDATE Sessions
       SET LastSeenAt = GREATEST(LastSeenAt, NEW.CreatedAt)
     WHERE SessionId = NEW.SessionId;
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS GetSessionFunnel;
DELIMITER //
CREATE PROCEDURE GetSessionFunnel(IN from_utc datetime, IN to_utc datetime)
BEGIN
    SELECT
        COUNT(DISTINCT s.SessionId) AS sessions,
        COUNT(DISTINCT CASE WHEN e.EventType = 'product_view' THEN s.SessionId END) AS product_view_sessions,
        COUNT(DISTINCT CASE WHEN c.CartId IS NOT NULL THEN s.SessionId END) AS cart_sessions,
        COUNT(DISTINCT CASE WHEN c.IsCheckedOut THEN s.SessionId END) AS checkout_sessions
    FROM Sessions AS s
    LEFT JOIN Events AS e
        ON e.SessionId = s.SessionId
       AND e.CreatedAt >= from_utc
       AND e.CreatedAt < to_utc
    LEFT JOIN Carts AS c
        ON c.SessionId = s.SessionId
       AND c.AddedAt >= from_utc
       AND c.AddedAt < to_utc
    WHERE s.StartedAt >= from_utc
      AND s.StartedAt < to_utc;
END//
DELIMITER ;
