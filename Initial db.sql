-- =========================================
-- 1. CREATE DATABASE & TABLES
-- =========================================

DROP DATABASE IF EXISTS EventDB;
CREATE DATABASE EventDB;
USE EventDB;

CREATE TABLE Venues (
    VenueID INT AUTO_INCREMENT PRIMARY KEY,
    VenueName VARCHAR(100) NOT NULL,
    Address VARCHAR(255) NOT NULL
);

CREATE TABLE Events (
    EventID INT AUTO_INCREMENT PRIMARY KEY,
    EventName VARCHAR(100) NOT NULL,
    EventDate DATE NOT NULL,
    VenueID INT NOT NULL,
    TotalRegistered INT DEFAULT 0,
    FOREIGN KEY (VenueID) REFERENCES Venues(VenueID)
);

CREATE TABLE Guests (
    GuestID INT AUTO_INCREMENT PRIMARY KEY,
    GuestName VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE,
    PhoneNumber VARCHAR(20)
);

CREATE TABLE Organizers (
    OrganizerID INT AUTO_INCREMENT PRIMARY KEY,
    OrganizerName VARCHAR(100) NOT NULL,
    Address VARCHAR(255),
    PhoneNumber VARCHAR(20)
);

CREATE TABLE Registrations (
    RegistrationID INT AUTO_INCREMENT PRIMARY KEY,
    EventID INT NOT NULL,
    GuestID INT NOT NULL,
    RegistrationDate DATE NOT NULL,
    FOREIGN KEY (EventID) REFERENCES Events(EventID),
    FOREIGN KEY (GuestID) REFERENCES Guests(GuestID),
    UNIQUE (EventID, GuestID)
);

-- =========================================
-- 2. INSERT VENUES (510)
-- =========================================

DELIMITER $$

CREATE PROCEDURE insert_venues()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 510 DO
        INSERT INTO Venues (VenueName, Address)
        VALUES (
            CONCAT('Venue ', i),
            CONCAT('Address ', i, 'Ha Noi')
        );
        SET i = i + 1;
    END WHILE;
END $$

DELIMITER ;

CALL insert_venues();

-- =========================================
-- 3. INSERT EVENTS (10)
-- =========================================

INSERT INTO Events (EventName, EventDate, VenueID) VALUES
('Tech Conference', '2026-06-01', 1),
('Music Festival', '2026-06-05', 2),
('Startup Meetup', '2026-06-10', 3),
('AI Workshop', '2026-06-15', 4),
('Business Forum', '2026-06-20', 5),
('Art Exhibition', '2026-06-25', 6),
('Gaming Event', '2026-07-01', 7),
('Education Fair', '2026-07-05', 8),
('Health Seminar', '2026-07-10', 9),
('Marketing Summit', '2026-07-15', 10);

-- =========================================
-- 4. INSERT GUESTS (510)
-- =========================================

DELIMITER $$

CREATE PROCEDURE insert_guests()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 510 DO
        INSERT INTO Guests (GuestName, Email, PhoneNumber)
        VALUES (
            CONCAT('Guest ', i),
            CONCAT('guest', i, '@gmail.com'),
            CONCAT('090', LPAD(i, 7, '0'))
        );
        SET i = i + 1;
    END WHILE;
END $$

DELIMITER ;

CALL insert_guests();

-- =========================================
-- 5. INSERT ORGANIZERS (510)
-- =========================================

DELIMITER $$

CREATE PROCEDURE insert_organizers()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 510 DO
        INSERT INTO Organizers (OrganizerName, Address, PhoneNumber)
        VALUES (
            CONCAT('Organizer ', i),
            CONCAT('Address ', i),
            CONCAT('091', LPAD(i, 7, '0'))
        );
        SET i = i + 1;
    END WHILE;
END $$

DELIMITER ;

CALL insert_organizers();

-- =========================================
-- 6. INSERT REGISTRATIONS (510, NO DUPLICATE)
-- =========================================

DELIMITER $$

CREATE PROCEDURE insert_registrations()
BEGIN
    WHILE (SELECT COUNT(*) FROM Registrations) < 510 DO
        INSERT IGNORE INTO Registrations (EventID, GuestID, RegistrationDate)
        VALUES (
            FLOOR(1 + RAND()*10),
            FLOOR(1 + RAND()*510),
            DATE_ADD('2026-05-01', INTERVAL FLOOR(RAND()*60) DAY)
        );
    END WHILE;
END $$

DELIMITER ;

CALL insert_registrations();

-- =========================================
-- 7. CHECK DATA
-- =========================================

SELECT 'Venues' AS TableName, COUNT(*) FROM Venues;
SELECT 'Guests' AS TableName, COUNT(*) FROM Guests;
SELECT 'Organizers' AS TableName, COUNT(*) FROM Organizers;
SELECT 'Registrations' AS TableName, COUNT(*) FROM Registrations;
SELECT 'Events' AS TableName, COUNT(*) FROM Events;

SET SQL_SAFE_UPDATES = 0;

UPDATE Events e
SET TotalRegistered = (
    SELECT COUNT(*) 
    FROM Registrations r 
    WHERE r.EventID = e.EventID
);
--
-- SELECT * FROM Venues;        -- Xem tất cả địa điểm
-- SELECT * FROM Events;        -- Xem tất cả sự kiện
-- SELECT * FROM Guests;        -- Xem tất cả khách mời
-- SELECT * FROM Organizers;    -- Xem tất cả nhà tổ chức
-- SELECT * FROM Registrations; -- Xem tất cả danh sách đăng ký
