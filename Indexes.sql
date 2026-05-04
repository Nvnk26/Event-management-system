-- Tăng tốc tìm theo EventID
CREATE INDEX idx_reg_event ON Registrations(EventID);

-- Tăng tốc tìm theo GuestID
CREATE INDEX idx_reg_guest ON Registrations(GuestID);

-- Tăng tốc lookup email (search khách)
CREATE INDEX idx_guest_email ON Guests(Email);

-- Kiểm tra
EXPLAIN SELECT * FROM Guests WHERE GuestID = '1';
EXPLAIN SELECT * FROM Guests WHERE Email = 'guest50@gmail.com';

-- ========================================================
-- 1. VIEW: TONG QUAN SU KIEN (vw_EventOverview)
-- Muc tieu: Ket hop thong tin su kien voi ten dia diem cu the
-- ========================================================
CREATE OR REPLACE VIEW vw_EventOverview AS
SELECT
    e.EventID,           -- ID cua su kien
    e.EventName,         -- Ten su kien
    e.EventDate,         -- Ngay dien ra
    v.VenueName,         -- Ten dia diem to chuc (lay tu bang Venues)
    v.Address AS VenueAddress, -- Dia chi chi tiet cua dia diem
    e.TotalRegistered    -- Tong so luong khach da dang ky
FROM Events e
JOIN Venues v ON e.VenueID = v.VenueID;

SELECT * FROM vw_EventOverview;


-- ========================================================
-- 2. VIEW: CHI TIET DANG KY (vw_GuestRegistrations)
-- Muc tieu: Hien thi danh sach khach moi theo su kien va thoi gian
-- ========================================================
CREATE OR REPLACE VIEW vw_GuestRegistrations AS
SELECT
    r.RegistrationID,    -- ID ban ghi dang ky
    e.EventName,         -- Ten su kien khach dang ky tham gia
    g.GuestName,         -- Ten day du cua khach moi
    g.Email,             -- Email cua khach de lien lac
    r.RegistrationDate   -- Ngay khach thuc hien dang ky thanh cong
FROM Registrations r
JOIN Events e ON r.EventID = e.EventID
JOIN Guests g ON r.GuestID = g.GuestID
ORDER BY e.EventName ASC, r.RegistrationDate DESC;

SELECT * FROM vw_GuestRegistrations;


-- ========================================================
-- 3. VIEW: PHAN LOAI QUY MO (vw_EventScale)
-- Muc tieu: Tu dong danh gia quy mo su kien dua tren so khach
-- ========================================================
CREATE OR REPLACE VIEW vw_EventScale AS
SELECT
    EventName,           -- Ten su kien
    TotalRegistered,     -- So luong khach hien co
    CASE
        WHEN TotalRegistered = 0 THEN 'No Registrations' -- Chua co ai dang ky
        WHEN TotalRegistered < 45 THEN 'Small Scale'     -- Quy mo nho (<50 nguoi)
        WHEN TotalRegistered < 55 THEN 'Medium Scale'   -- Quy mo vua (50-99 nguoi)
        ELSE 'Large Scale'                               -- Quy mo lon (>=100 nguoi)
    END AS ScaleStatus   -- Cot hien thi trang thai quy mo
FROM Events;

SELECT * FROM vw_EventScale;

-- ========================================================
-- 1. STORED PROCEDURE: DANG KY KHACH MOI (sp_RegisterGuest)
-- Muc tieu: Dang ky khach vao su kien va tu dong tang TotalRegistered
-- ========================================================
DELIMITER //

CREATE PROCEDURE sp_RegisterGuest(
    IN p_EventID INT,
    IN p_GuestID INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;
        -- Chen ban ghi moi vao bang dang ky
        INSERT INTO Registrations (EventID, GuestID, RegistrationDate)
        VALUES (p_EventID, p_GuestID, CURDATE());

        -- Tu dong cap nhat so luong o bang Events
        UPDATE Events 
        SET TotalRegistered = TotalRegistered + 1
        WHERE EventID = p_EventID;
    COMMIT;
END //

DELIMITER ;

-- Test thu tuc 1: Dang ky Guest ID 1 vao Event ID 2
CALL sp_RegisterGuest(2, 1);
SELECT * FROM Registrations ORDER BY RegistrationID DESC LIMIT 1;
SELECT * FROM Events WHERE EventID = 2;


-- ========================================================
-- 2. STORED PROCEDURE: THONG KE SU KIEN (sp_GetEventAnalytics)
-- Muc tieu: Xem nhanh thong tin su kien va so luong khach thuc te
-- ========================================================
DELIMITER //

CREATE PROCEDURE sp_GetEventAnalytics(IN p_EventID INT)
BEGIN
    SELECT 
        e.EventName,
        v.VenueName,
        e.EventDate,
        e.TotalRegistered,
        (SELECT COUNT(*) FROM Registrations WHERE EventID = p_EventID) AS VerifiedCount
    FROM Events e
    JOIN Venues v ON e.VenueID = v.VenueID
    WHERE e.EventID = p_EventID;
END //

DELIMITER ;

-- Test thu tuc 2: Xem thong ke cho Event ID 1
CALL sp_GetEventAnalytics(1);


-- ========================================================
-- 3. STORED PROCEDURE: XOA SU KIEN AN TOAN (sp_DeleteEvent)
-- Muc tieu: Xoa dang ky lien quan truoc khi xoa su kien
-- ========================================================
DELIMITER //

CREATE PROCEDURE sp_DeleteEvent(IN p_EventID INT)
BEGIN
    -- Xoa dang ky truoc de tranh loi khoa ngoai
    DELETE FROM Registrations WHERE EventID = p_EventID;
    
    -- Xoa su kien sau
    DELETE FROM Events WHERE EventID = p_EventID;
    
    SELECT CONCAT('Da xoa thanh cong su kien ID: ', p_EventID) AS Message;
END //

DELIMITER ;

-- Test thu tuc 3: Xoa su kien (Mac dinh dang comment de tranh xoa nham)
-- CALL sp_DeleteEvent(10);
-- SELECT * FROM Events;

-- =========================================
-- FUNCTIONS: tính toán tái sử dụng
-- =========================================
DROP FUNCTION TotalGuests
-- 1. Total Guests per Event
DELIMITER $$

CREATE FUNCTION TotalGuests(event_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total INT;

    SELECT COUNT(*) INTO total
    FROM Registrations
    WHERE EventID = event_id;

    RETURN total;
END $$

DELIMITER ;
-- 👉 Feature: trả về tổng số khách của 1 event

------------------------------------------------

-- 2. Participation Rate (%)
DELIMITER $$

CREATE FUNCTION ParticipationRate(event_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE total INT;
    DECLARE total_guests INT;

    SELECT COUNT(*) INTO total
    FROM Registrations
    WHERE EventID = event_id;

    SELECT COUNT(*) INTO total_guests
    FROM Guests;

    RETURN ROUND((total * 100.0) / total_guests, 2);
END $$

DELIMITER ;
-- Test
SELECT 
    EventName,
    TotalGuests(EventID) AS SoKhach,
    ParticipationRate(EventID) AS Percent
FROM Events;
-- =========================================
-- VENUE USAGE
-- =========================================

SELECT 
    v.VenueName,
    COUNT(e.EventID) AS TotalEvents
FROM Venues v
LEFT JOIN Events e ON v.VenueID = e.VenueID
GROUP BY v.VenueID;

-- 👉 Feature:
-- - Xem venue nào được sử dụng nhiều

DELIMITER $$

CREATE TRIGGER tg_AfterRegistration
AFTER INSERT ON Registrations
FOR EACH ROW
BEGIN
    -- Tu dong tang so luong khach khi co ban ghi moi
    UPDATE Events 
    SET TotalRegistered = TotalRegistered + 1
    WHERE EventID = NEW.EventID;
END $$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER tg_BeforeRegistration
BEFORE INSERT ON Registrations
FOR EACH ROW
BEGIN
    DECLARE current_count INT;
    
    -- Lay so luong khach hien tai cua su kien
    SELECT TotalRegistered INTO current_count 
    FROM Events 
    WHERE EventID = NEW.EventID;
    
    -- Neu vuot qua suc chua (vi du 100), se chan dang ky
    IF current_count >= 100 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Loi: Su kien nay da day cho!';
    END IF;
END $$

DELIMITER ;
-- =========================================
-- ACCESS ROLES 
-- =========================================

-- App user (cho Python)
CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'fullfunction1';
GRANT ALL PRIVILEGES ON EventDB.* TO 'app_user'@'localhost';

-- Staff
CREATE USER IF NOT EXISTS 'staff'@'localhost' IDENTIFIED BY '123456';

GRANT SELECT ON EventDB.Events TO 'staff'@'localhost';
GRANT SELECT ON EventDB.Guests TO 'staff'@'localhost';
GRANT SELECT, INSERT ON EventDB.Registrations TO 'staff'@'localhost';


-- =========================================
-- DATA SECURITY: bảo vệ thông tin nhạy cảm
-- =========================================



-- ========================================================
-- 1. VIEW: BAO MAT THONG TIN KHACH (Guest_Public)
-- Muc tieu: Masking cac thong tin nhay cam de staff van co the lam viec 
-- nhung khong thay duoc toan bo du lieu ca nhan.
-- ========================================================
CREATE OR REPLACE VIEW Guest_Public AS
SELECT 
    GuestID,
    GuestName,

    -- An email: chi hien 3 ky tu dau va thay the phan con lai
    CONCAT(LEFT(Email, 3), '***@gmail.com') AS Masked_Email,

    -- An so dien thoai: chi de lai 2 so cuoi
    CONCAT('******', RIGHT(PhoneNumber, 2)) AS Masked_Phone

FROM Guests;

-- Kiem tra View bao mat
SELECT * FROM Guest_Public;


-- 2. Query tối ưu (dùng JOIN + GROUP BY)
SELECT 
    e.EventName,
    COUNT(r.RegistrationID) AS Total
FROM Events e
LEFT JOIN Registrations r ON e.EventID = r.EventID
GROUP BY e.EventID;

-- 👉 Feature:
-- - Truy vấn nhanh và hiệu quả

------------------------------------------------

-- 3. Bulk Insert (thêm nhiều dòng cùng lúc)
INSERT INTO Registrations (EventID, GuestID, RegistrationDate)
VALUES
(1,1,'2026-06-01'),
(1,2,'2026-06-01'),
(1,3,'2026-06-01');

-- 👉 Feature:
-- - Nhanh hơn insert từng dòng
