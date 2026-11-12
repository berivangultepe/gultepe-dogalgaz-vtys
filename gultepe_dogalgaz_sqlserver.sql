-- =====================================================================
-- Gültepe Doğalgaz Mühendislik
-- Doğalgaz Taahhüt, Keşif ve Proje Onay Takip Sistemi
-- VTYS II - 6. Hafta: Fiziksel veritabanı (Microsoft SQL Server 2016+)
--
-- Çalıştırma: SSMS'te dosyayı açıp tamamını çalıştırın (F5).
--   Dosya UTF-8 (BOM'lu) kaydedilmiştir; Türkçe karakterler için N'...' kullanılır.
--   sqlcmd ile: sqlcmd -S <sunucu> -E -I -f 65001 -i dosya.sql
--   (-I: QUOTED_IDENTIFIER ON; filtreli indeksler için gereklidir)
--
-- Not: Tablolar arası kurallar (İK-04, 05, 08, 10, 13, 17, 19) trigger ve
--      saklı yordam gerektirir; 7. Hafta'da eklenecektir.
-- =====================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ---------------------------------------------------------------------
-- 0. VERİTABANI
-- ---------------------------------------------------------------------
IF DB_ID(N'GultepeDogalgaz') IS NULL
    CREATE DATABASE GultepeDogalgaz COLLATE Turkish_CI_AS;
GO
USE GultepeDogalgaz;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ---------------------------------------------------------------------
-- 1. TABLOLAR (yeniden çalıştırılabilir: önce çocuk tablolar silinir)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS PROJE_REVIZYON_LOG;
DROP TABLE IF EXISTS RANDEVU;
DROP TABLE IF EXISTS PROJE_DOSYASI;
DROP TABLE IF EXISTS KESIF;
DROP TABLE IF EXISTS DAIRE;
DROP TABLE IF EXISTS MUSTERI;
GO

CREATE TABLE MUSTERI (
    MusteriID    INT IDENTITY(1,1) NOT NULL,
    AdSoyad      NVARCHAR(100) NOT NULL,
    Telefon      NVARCHAR(20)  NOT NULL,
    KayitTarihi  DATE          NOT NULL CONSTRAINT DF_MUSTERI_KayitTarihi DEFAULT (CAST(GETDATE() AS DATE)),
    CONSTRAINT PK_MUSTERI         PRIMARY KEY (MusteriID),
    CONSTRAINT CK_MUSTERI_AdSoyad CHECK (LEN(LTRIM(RTRIM(AdSoyad))) > 0),
    CONSTRAINT CK_MUSTERI_Telefon CHECK (LEN(LTRIM(RTRIM(Telefon))) >= 10)
);
GO

CREATE TABLE DAIRE (
    DaireID      INT IDENTITY(1,1) NOT NULL,
    MusteriID    INT           NOT NULL,
    Adres        NVARCHAR(250) NOT NULL,
    Ilce         NVARCHAR(50)  NULL,
    TesisatTuru  NVARCHAR(15)  NOT NULL CONSTRAINT DF_DAIRE_TesisatTuru DEFAULT (N'Bireysel'),
    AboneNo      NVARCHAR(20)  NULL,
    TesisatNo    NVARCHAR(20)  NULL,
    CONSTRAINT PK_DAIRE             PRIMARY KEY (DaireID),
    CONSTRAINT FK_DAIRE_MUSTERI     FOREIGN KEY (MusteriID) REFERENCES MUSTERI (MusteriID)
                                    ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_DAIRE_TesisatTuru CHECK (TesisatTuru IN (N'Bireysel', N'Bina Kolon', N'Ticari'))
);
GO

CREATE TABLE KESIF (
    KesifID            INT IDENTITY(1,1) NOT NULL,
    DaireID            INT            NOT NULL,
    KesifTarihi        DATE           NOT NULL,
    PetekMetraji       DECIMAL(8,2)   NOT NULL,
    KombiTipi          NVARCHAR(12)   NOT NULL,
    KombiModeli        NVARCHAR(100)  NULL,
    OnerilenBedel      DECIMAL(12,2)  NULL,
    TahminiIsBedeli    DECIMAL(12,2)  NOT NULL,
    BedelRevizeNedeni  NVARCHAR(250)  NULL,
    TeklifDurumu       NVARCHAR(15)   NOT NULL CONSTRAINT DF_KESIF_TeklifDurumu DEFAULT (N'Teklif Verildi'),
    Notlar             NVARCHAR(500)  NULL,
    CONSTRAINT PK_KESIF           PRIMARY KEY (KesifID),
    CONSTRAINT FK_KESIF_DAIRE     FOREIGN KEY (DaireID) REFERENCES DAIRE (DaireID)
                                  ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_KESIF_Petek     CHECK (PetekMetraji >= 0),
    CONSTRAINT CK_KESIF_KombiTipi CHECK (KombiTipi IN (N'Yoğuşmalı', N'Klasik', N'Yok')),
    CONSTRAINT CK_KESIF_Onerilen  CHECK (OnerilenBedel IS NULL OR OnerilenBedel >= 0),
    CONSTRAINT CK_KESIF_Tahmini   CHECK (TahminiIsBedeli >= 0),
    CONSTRAINT CK_KESIF_Teklif    CHECK (TeklifDurumu IN (N'Teklif Verildi', N'Kabul Edildi', N'Reddedildi')),
    -- İK-07: nihai bedel öneriden farklıysa revize nedeni zorunlu
    CONSTRAINT CK_KESIF_Revize    CHECK (OnerilenBedel IS NULL
                                         OR TahminiIsBedeli = OnerilenBedel
                                         OR BedelRevizeNedeni IS NOT NULL)
);
GO

CREATE TABLE PROJE_DOSYASI (
    ProjeID         INT IDENTITY(1,1) NOT NULL,
    KesifID         INT           NOT NULL,
    DagitimSirketi  NVARCHAR(10)  NULL,
    DagitimTakipNo  NVARCHAR(30)  NULL,
    Durum           NVARCHAR(15)  NOT NULL CONSTRAINT DF_PROJE_Durum DEFAULT (N'Çizimde'),
    BasvuruTarihi   DATE          NULL,
    OnayTarihi      DATE          NULL,
    CONSTRAINT PK_PROJE          PRIMARY KEY (ProjeID),
    CONSTRAINT FK_PROJE_KESIF    FOREIGN KEY (KesifID) REFERENCES KESIF (KesifID)
                                 ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_PROJE_Kesif    UNIQUE (KesifID),   -- İK-09: keşif başına en fazla bir proje
    CONSTRAINT CK_PROJE_Durum    CHECK (Durum IN (N'Çizimde', N'Dağıtımda', N'Ret', N'Onaylandı', N'Gaz Açıldı')),
    CONSTRAINT CK_PROJE_Sirket   CHECK (DagitimSirketi IS NULL OR DagitimSirketi IN (N'İGDAŞ', N'Aksa', N'Diğer')),
    -- İK-11: Çizimde dışındaki durumlarda başvuru bilgileri dolu olmalı
    CONSTRAINT CK_PROJE_Basvuru  CHECK (Durum = N'Çizimde'
                                        OR (DagitimSirketi IS NOT NULL
                                            AND DagitimTakipNo IS NOT NULL
                                            AND BasvuruTarihi IS NOT NULL)),
    -- Onaylandı / Gaz Açıldı durumlarında onay tarihi dolu olmalı
    CONSTRAINT CK_PROJE_OnayDolu CHECK (Durum NOT IN (N'Onaylandı', N'Gaz Açıldı') OR OnayTarihi IS NOT NULL),
    -- İK-14
    CONSTRAINT CK_PROJE_Tarih    CHECK (OnayTarihi IS NULL OR BasvuruTarihi IS NULL OR OnayTarihi >= BasvuruTarihi)
);
GO

CREATE TABLE RANDEVU (
    RandevuID         INT IDENTITY(1,1) NOT NULL,
    DaireID           INT           NOT NULL,
    ProjeID           INT           NULL,
    RandevuTuru       NVARCHAR(10)  NOT NULL,
    RandevuTarihSaat  DATETIME2(0)  NOT NULL,
    Sonuc             NVARCHAR(10)  NOT NULL CONSTRAINT DF_RANDEVU_Sonuc DEFAULT (N'Bekliyor'),
    Notlar            NVARCHAR(500) NULL,
    CONSTRAINT PK_RANDEVU        PRIMARY KEY (RandevuID),
    CONSTRAINT FK_RANDEVU_DAIRE  FOREIGN KEY (DaireID) REFERENCES DAIRE (DaireID)
                                 ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_RANDEVU_PROJE  FOREIGN KEY (ProjeID) REFERENCES PROJE_DOSYASI (ProjeID)
                                 ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_RANDEVU_Turu   CHECK (RandevuTuru IN (N'Keşif', N'Gaz Açım')),
    CONSTRAINT CK_RANDEVU_Sonuc  CHECK (Sonuc IN (N'Bekliyor', N'Yapıldı', N'Ertelendi', N'İptal')),
    -- İK-16: gaz açım randevusunda proje zorunlu, keşif randevusunda boş
    CONSTRAINT CK_RANDEVU_Proje  CHECK ((RandevuTuru = N'Gaz Açım' AND ProjeID IS NOT NULL)
                                        OR (RandevuTuru = N'Keşif' AND ProjeID IS NULL))
);
GO

CREATE TABLE PROJE_REVIZYON_LOG (
    LogID         INT IDENTITY(1,1) NOT NULL,
    ProjeID       INT           NOT NULL,
    EskiDurum     NVARCHAR(15)  NULL,
    YeniDurum     NVARCHAR(15)  NOT NULL,
    RetGerekcesi  NVARCHAR(500) NULL,
    IslemTarihi   DATETIME2(0)  NOT NULL CONSTRAINT DF_LOG_IslemTarihi DEFAULT (SYSDATETIME()),
    IslemYapan    NVARCHAR(20)  NOT NULL,
    CONSTRAINT PK_LOG       PRIMARY KEY (LogID),
    CONSTRAINT FK_LOG_PROJE FOREIGN KEY (ProjeID) REFERENCES PROJE_DOSYASI (ProjeID)
                            ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_LOG_Eski  CHECK (EskiDurum IS NULL OR EskiDurum IN (N'Çizimde', N'Dağıtımda', N'Ret', N'Onaylandı', N'Gaz Açıldı')),
    CONSTRAINT CK_LOG_Yeni  CHECK (YeniDurum IN (N'Çizimde', N'Dağıtımda', N'Ret', N'Onaylandı', N'Gaz Açıldı')),
    CONSTRAINT CK_LOG_Yapan CHECK (IslemYapan IN (N'Yetkili Mühendis', N'Ofis Asistanı')),
    -- İK-12: ret geçişinde gerekçe zorunlu, diğer geçişlerde boş
    CONSTRAINT CK_LOG_Ret   CHECK ((YeniDurum = N'Ret' AND RetGerekcesi IS NOT NULL AND LEN(LTRIM(RTRIM(RetGerekcesi))) > 0)
                                   OR (YeniDurum <> N'Ret' AND RetGerekcesi IS NULL))
);
GO

-- ---------------------------------------------------------------------
-- 2. İNDEKSLER
-- SQL Server'da UNIQUE kısıt yalnızca bir NULL kabul eder; AboneNo, TesisatNo ve
-- DagitimTakipNo boş olabildiği için benzersizlik FİLTRELİ UNIQUE İNDEKS ile sağlanır.
-- ---------------------------------------------------------------------
CREATE UNIQUE INDEX UQ_DAIRE_AboneNo      ON DAIRE (AboneNo)            WHERE AboneNo IS NOT NULL;
CREATE UNIQUE INDEX UQ_DAIRE_TesisatNo    ON DAIRE (TesisatNo)          WHERE TesisatNo IS NOT NULL;
CREATE UNIQUE INDEX UQ_PROJE_TakipNo      ON PROJE_DOSYASI (DagitimTakipNo) WHERE DagitimTakipNo IS NOT NULL;

-- İK-15: tek mühendis, aynı tarih-saatte yalnızca bir aktif randevu
CREATE UNIQUE INDEX UX_RANDEVU_Aktif_TarihSaat
    ON RANDEVU (RandevuTarihSaat) WHERE Sonuc = N'Bekliyor';

-- Yabancı anahtar indeksleri (JOIN ve silme kontrolü performansı)
CREATE INDEX IX_DAIRE_MusteriID     ON DAIRE (MusteriID);
CREATE INDEX IX_KESIF_DaireID       ON KESIF (DaireID);
CREATE INDEX IX_RANDEVU_DaireID     ON RANDEVU (DaireID);
CREATE INDEX IX_RANDEVU_ProjeID     ON RANDEVU (ProjeID) WHERE ProjeID IS NOT NULL;
CREATE INDEX IX_LOG_ProjeID_Tarih   ON PROJE_REVIZYON_LOG (ProjeID, IslemTarihi);

-- Arama ve rapor sorgularına yönelik indeksler
CREATE INDEX IX_MUSTERI_AdSoyad     ON MUSTERI (AdSoyad);
CREATE INDEX IX_MUSTERI_Telefon     ON MUSTERI (Telefon);
CREATE INDEX IX_KESIF_Teklif_Tarih  ON KESIF (TeklifDurumu, KesifTarihi);        -- R4, K1
CREATE INDEX IX_PROJE_Durum_Basvuru ON PROJE_DOSYASI (Durum, BasvuruTarihi);     -- R2
CREATE INDEX IX_RANDEVU_TarihSaat   ON RANDEVU (RandevuTarihSaat);               -- R6, haftalık plan
CREATE INDEX IX_LOG_YeniDurum_Proje ON PROJE_REVIZYON_LOG (YeniDurum, ProjeID);  -- R1, R3
GO

-- ---------------------------------------------------------------------
-- 3. ÖRNEK VERİ (anonim, kurgusal)
-- Örnek bedel katsayıları (gerçek değil): petek 750 TL/m, kombi tipi
-- Yoğuşmalı 12.000 / Klasik 8.000 / Yok 0, sabit proje bedeli 5.000.
-- OnerilenBedel = PetekMetraji x 750 + kombi tipi bedeli + 5.000
-- Kimlikler (IDENTITY) açıkça verildiği için IDENTITY_INSERT kullanılır;
-- sayaç otomatik olarak en büyük değerden devam eder.
-- ---------------------------------------------------------------------

SET IDENTITY_INSERT MUSTERI ON;
INSERT INTO MUSTERI (MusteriID, AdSoyad, Telefon, KayitTarihi) VALUES
 (1,  N'Ayşe Yılmaz',              N'0500 000 00 01', '2026-08-10'),
 (2,  N'Mehmet Demir',             N'0500 000 00 02', '2026-08-12'),
 (3,  N'Fatma Kaya',               N'0500 000 00 03', '2026-08-18'),
 (4,  N'Ali Çelik',                N'0500 000 00 04', '2026-08-22'),
 (5,  N'Zeynep Şahin',             N'0500 000 00 05', '2026-08-30'),
 (6,  N'Mustafa Aydın',            N'0500 000 00 06', '2026-09-03'),
 (7,  N'Elif Özdemir',             N'0500 000 00 07', '2026-09-08'),
 (8,  N'Hasan Arslan',             N'0500 000 00 08', '2026-09-09'),
 (9,  N'Emine Doğan',              N'0500 000 00 09', '2026-09-13'),
 (10, N'Hüseyin Kılıç',            N'0500 000 00 10', '2026-09-20'),
 (11, N'Merve Yıldız',             N'0500 000 00 11', '2026-09-30'),
 (12, N'Ahmet Koç',                N'0500 000 00 12', '2026-09-28'),
 (13, N'Gül Market Ltd. Şti.',     N'0500 000 00 13', '2026-10-14'),
 (14, N'Çınar Apartmanı Yönetimi', N'0500 000 00 14', '2026-09-15');
SET IDENTITY_INSERT MUSTERI OFF;
GO

SET IDENTITY_INSERT DAIRE ON;
INSERT INTO DAIRE (DaireID, MusteriID, Adres, Ilce, TesisatTuru, AboneNo, TesisatNo) VALUES
 (1,  1,  N'Bahariye Cad. No:12 D:3',            N'Kadıköy',    N'Bireysel',   N'10000001', N'20000001'),
 (2,  2,  N'Moda Sok. No:5 D:2',                 N'Kadıköy',    N'Bireysel',   N'10000002', N'20000002'),
 (3,  3,  N'Atatürk Mah. 14. Sok. No:8 D:1',    N'Ümraniye',   N'Bireysel',   N'10000003', N'20000003'),
 (4,  4,  N'Çarşı Mah. Gül Sok. No:21 D:6',     N'Üsküdar',    N'Bireysel',   N'10000004', N'20000004'),
 (5,  5,  N'Barbaros Bulv. No:77 D:9',           N'Beşiktaş',   N'Bireysel',   N'10000005', N'20000005'),
 (6,  5,  N'Barbaros Bulv. No:77 D:10',          N'Beşiktaş',   N'Bireysel',   NULL,       NULL),
 (7,  6,  N'Yeni Mah. Lale Sok. No:3 D:4',      N'Maltepe',    N'Bireysel',   N'10000007', N'20000007'),
 (8,  7,  N'Cumhuriyet Mah. 3. Cad. No:30 D:5', N'Pendik',     N'Bireysel',   NULL,       NULL),
 (9,  8,  N'Fevzi Çakmak Cad. No:44 D:2',       N'Kartal',     N'Bireysel',   N'10000009', N'20000009'),
 (10, 9,  N'İnönü Mah. Çiçek Sok. No:9 D:7',    N'Sancaktepe', N'Bireysel',   N'10000010', N'20000010'),
 (11, 10, N'Kozyatağı Mah. Işık Sok. No:16 D:8',N'Kadıköy',    N'Bireysel',   N'10000011', N'20000011'),
 (12, 11, N'Altunizade Mah. Selvi Sok. No:2 D:1',N'Üsküdar',    N'Bireysel',   NULL,       NULL),
 (13, 12, N'Esentepe Mah. Gül Cad. No:60 D:12',  N'Şişli',      N'Bireysel',   N'10000013', N'20000013'),
 (14, 14, N'Çınar Apt. A Blok, Bağdat Cad. No:210',N'Kadıköy',  N'Bina Kolon', NULL,       NULL),
 (15, 13, N'Gül Market, Bağdat Cad. No:188',     N'Kadıköy',    N'Ticari',     N'10000015', N'20000015'),
 (16, 14, N'Çınar Apt. B Blok, Bağdat Cad. No:212',N'Kadıköy',  N'Bina Kolon', NULL,       NULL);
SET IDENTITY_INSERT DAIRE OFF;
GO

SET IDENTITY_INSERT KESIF ON;
INSERT INTO KESIF (KesifID, DaireID, KesifTarihi, PetekMetraji, KombiTipi, KombiModeli,
                   OnerilenBedel, TahminiIsBedeli, BedelRevizeNedeni, TeklifDurumu, Notlar) VALUES
 (1,  1,  '2026-08-12', 18.50, N'Yoğuşmalı', N'Model A 24 kW', 30875.00, 28500.00, N'Müşteri ile pazarlık',           N'Kabul Edildi',  NULL),
 (2,  2,  '2026-08-14', 22.00, N'Klasik',    N'Model B 24 kW', 29500.00, 29500.00, NULL,                            N'Kabul Edildi',  NULL),
 (3,  3,  '2026-08-20', 15.00, N'Yoğuşmalı', N'Model A 24 kW', 28250.00, 28250.00, NULL,                            N'Kabul Edildi',  NULL),
 (4,  4,  '2026-08-25', 30.00, N'Yoğuşmalı', N'Model C 28 kW', 39500.00, 36000.00, N'Müşteri ile pazarlık',           N'Kabul Edildi',  NULL),
 (5,  5,  '2026-09-02', 26.00, N'Yoğuşmalı', N'Model A 24 kW', 36500.00, 36500.00, NULL,                            N'Kabul Edildi',  NULL),
 (6,  7,  '2026-09-05', 12.00, N'Yok',       NULL,            14000.00, 14000.00, NULL,                            N'Reddedildi',    N'Müşteri teklifi yüksek buldu'),
 (7,  9,  '2026-09-10', 20.00, N'Klasik',    N'Model B 24 kW', 28000.00, 31000.00, N'Ek kolon bağlantısı gerekli',   N'Kabul Edildi',  NULL),
 (8,  10, '2026-09-15', 16.50, N'Yoğuşmalı', N'Model A 24 kW', 29375.00, 29375.00, NULL,                            N'Kabul Edildi',  NULL),
 (9,  11, '2026-09-22', 28.00, N'Yoğuşmalı', N'Model C 28 kW', 38000.00, 38000.00, NULL,                            N'Kabul Edildi',  NULL),
 (10, 13, '2026-10-01', 19.00, N'Klasik',    N'Model B 24 kW', 27250.00, 27250.00, NULL,                            N'Kabul Edildi',  NULL),
 (11, 6,  '2026-10-06', 21.00, N'Yoğuşmalı', N'Model A 24 kW', 32750.00, 32750.00, NULL,                            N'Kabul Edildi',  NULL),
 (12, 8,  '2026-10-09', 17.00, N'Klasik',    N'Model B 24 kW', 25750.00, 25750.00, NULL,                            N'Teklif Verildi',NULL),
 (13, 12, '2026-10-13', 24.00, N'Yoğuşmalı', N'Model C 28 kW', 35000.00, 33000.00, N'Müşteri ile pazarlık',           N'Kabul Edildi',  NULL),
 (14, 14, '2026-09-18', 0.00,  N'Yok',       NULL,            NULL,     185000.00,NULL,                            N'Kabul Edildi',  N'A blok kolon hattı yenileme'),
 (15, 15, '2026-10-16', 24.00, N'Yok',       NULL,            NULL,     96000.00, NULL,                            N'Kabul Edildi',  N'İş yeri tesisatı, 3 cihaz bağlantısı'),
 (16, 1,  '2026-10-28', 6.00,  N'Yok',       NULL,            9500.00,  9500.00,  NULL,                            N'Teklif Verildi',N'Ek petek hattı');
SET IDENTITY_INSERT KESIF OFF;
GO

SET IDENTITY_INSERT PROJE_DOSYASI ON;
INSERT INTO PROJE_DOSYASI (ProjeID, KesifID, DagitimSirketi, DagitimTakipNo, Durum, BasvuruTarihi, OnayTarihi) VALUES
 (1,  1,  N'İGDAŞ', N'IGD-2026-00123', N'Gaz Açıldı', '2026-08-20', '2026-09-03'),
 (2,  2,  N'İGDAŞ', N'IGD-2026-00131', N'Gaz Açıldı', '2026-08-24', '2026-09-10'),
 (3,  3,  N'Aksa',  N'AKS-2026-00457', N'Onaylandı',  '2026-09-01', '2026-09-20'),
 (4,  4,  N'İGDAŞ', N'IGD-2026-00160', N'Ret',        '2026-09-08', NULL),
 (5,  5,  N'Aksa',  N'AKS-2026-00502', N'Dağıtımda',  '2026-09-16', NULL),
 (6,  7,  N'İGDAŞ', N'IGD-2026-00188', N'Gaz Açıldı', '2026-09-18', '2026-10-02'),
 (7,  8,  N'Aksa',  N'AKS-2026-00533', N'Dağıtımda',  '2026-09-25', NULL),
 (8,  9,  NULL,    NULL,             N'Çizimde',    NULL,         NULL),
 (9,  10, N'İGDAŞ', N'IGD-2026-00207', N'Onaylandı',  '2026-10-07', '2026-10-21'),
 (10, 14, N'İGDAŞ', N'IGD-2026-00175', N'Ret',        '2026-10-01', NULL);
SET IDENTITY_INSERT PROJE_DOSYASI OFF;
GO

SET IDENTITY_INSERT RANDEVU ON;
INSERT INTO RANDEVU (RandevuID, DaireID, ProjeID, RandevuTuru, RandevuTarihSaat, Sonuc, Notlar) VALUES
 (1,  1,  NULL, N'Keşif',    '2026-08-12 10:00', N'Yapıldı',   NULL),
 (2,  2,  NULL, N'Keşif',    '2026-08-14 11:00', N'Yapıldı',   NULL),
 (3,  3,  NULL, N'Keşif',    '2026-08-20 09:30', N'Yapıldı',   NULL),
 (4,  4,  NULL, N'Keşif',    '2026-08-25 14:00', N'Yapıldı',   NULL),
 (5,  5,  NULL, N'Keşif',    '2026-09-02 10:30', N'Yapıldı',   NULL),
 (6,  7,  NULL, N'Keşif',    '2026-09-05 16:00', N'Yapıldı',   NULL),
 (7,  9,  NULL, N'Keşif',    '2026-09-10 13:00', N'Yapıldı',   NULL),
 (8,  10, NULL, N'Keşif',    '2026-09-15 11:30', N'Yapıldı',   NULL),
 (9,  11, NULL, N'Keşif',    '2026-09-22 10:00', N'Yapıldı',   NULL),
 (10, 14, NULL, N'Keşif',    '2026-09-18 15:00', N'Yapıldı',   NULL),
 (11, 13, NULL, N'Keşif',    '2026-10-01 09:30', N'Yapıldı',   NULL),
 (12, 6,  NULL, N'Keşif',    '2026-10-06 14:30', N'Yapıldı',   NULL),
 (13, 8,  NULL, N'Keşif',    '2026-10-09 10:00', N'Yapıldı',   NULL),
 (14, 12, NULL, N'Keşif',    '2026-10-13 11:00', N'Yapıldı',   NULL),
 (15, 15, NULL, N'Keşif',    '2026-10-16 15:30', N'Yapıldı',   NULL),
 (16, 1,  NULL, N'Keşif',    '2026-10-28 10:30', N'Yapıldı',   NULL),
 (17, 1,  1,    N'Gaz Açım', '2026-09-05 14:00', N'Yapıldı',   NULL),
 (18, 2,  2,    N'Gaz Açım', '2026-09-12 11:00', N'Yapıldı',   NULL),
 (19, 9,  6,    N'Gaz Açım', '2026-10-03 14:00', N'Ertelendi', N'Müşteri evde değildi'),
 (20, 9,  6,    N'Gaz Açım', '2026-10-05 15:30', N'Yapıldı',   NULL),
 (21, 3,  3,    N'Gaz Açım', '2026-11-10 10:00', N'Bekliyor',  NULL),
 (22, 16, NULL, N'Keşif',    '2026-10-30 09:00', N'İptal',     N'Müşteri vazgeçti, yeniden planlanacak'),
 (23, 16, NULL, N'Keşif',    '2026-11-12 10:00', N'Bekliyor',  NULL);
SET IDENTITY_INSERT RANDEVU OFF;
GO

SET IDENTITY_INSERT PROJE_REVIZYON_LOG ON;
INSERT INTO PROJE_REVIZYON_LOG (LogID, ProjeID, EskiDurum, YeniDurum, RetGerekcesi, IslemTarihi, IslemYapan) VALUES
 -- Proje 1
 (1,  1,  NULL,        N'Çizimde',    NULL, '2026-08-18 10:00', N'Yetkili Mühendis'),
 (2,  1,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-08-20 11:00', N'Yetkili Mühendis'),
 (3,  1,  N'Dağıtımda', N'Onaylandı',  NULL, '2026-09-03 09:30', N'Yetkili Mühendis'),
 (4,  1,  N'Onaylandı', N'Gaz Açıldı', NULL, '2026-09-05 15:00', N'Yetkili Mühendis'),
 -- Proje 2 (bir ret, sonra onay)
 (5,  2,  NULL,        N'Çizimde',    NULL, '2026-08-22 10:00', N'Yetkili Mühendis'),
 (6,  2,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-08-24 10:30', N'Yetkili Mühendis'),
 (7,  2,  N'Dağıtımda', N'Ret',        N'Eksik tesisat paftası', '2026-09-01 14:00', N'Yetkili Mühendis'),
 (8,  2,  N'Ret',       N'Çizimde',    NULL, '2026-09-02 09:00', N'Yetkili Mühendis'),
 (9,  2,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-09-03 10:00', N'Yetkili Mühendis'),
 (10, 2,  N'Dağıtımda', N'Onaylandı',  NULL, '2026-09-10 11:00', N'Yetkili Mühendis'),
 (11, 2,  N'Onaylandı', N'Gaz Açıldı', NULL, '2026-09-12 12:00', N'Yetkili Mühendis'),
 -- Proje 3
 (12, 3,  NULL,        N'Çizimde',    NULL, '2026-08-28 10:00', N'Yetkili Mühendis'),
 (13, 3,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-09-01 10:00', N'Yetkili Mühendis'),
 (14, 3,  N'Dağıtımda', N'Onaylandı',  NULL, '2026-09-20 09:45', N'Yetkili Mühendis'),
 -- Proje 4 (iki ret, hâlâ onaylanmadı)
 (15, 4,  NULL,        N'Çizimde',    NULL, '2026-09-05 10:00', N'Yetkili Mühendis'),
 (16, 4,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-09-08 10:00', N'Yetkili Mühendis'),
 (17, 4,  N'Dağıtımda', N'Ret',        N'Kolon hattı çapı yetersiz', '2026-09-17 13:00', N'Yetkili Mühendis'),
 (18, 4,  N'Ret',       N'Çizimde',    NULL, '2026-09-18 09:00', N'Yetkili Mühendis'),
 (19, 4,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-09-22 10:00', N'Yetkili Mühendis'),
 (20, 4,  N'Dağıtımda', N'Ret',        N'Sayaç yeri uygun değil', '2026-10-02 14:30', N'Yetkili Mühendis'),
 -- Proje 5
 (21, 5,  NULL,        N'Çizimde',    NULL, '2026-09-14 10:00', N'Yetkili Mühendis'),
 (22, 5,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-09-16 10:00', N'Yetkili Mühendis'),
 -- Proje 6
 (23, 6,  NULL,        N'Çizimde',    NULL, '2026-09-16 10:00', N'Yetkili Mühendis'),
 (24, 6,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-09-18 10:00', N'Yetkili Mühendis'),
 (25, 6,  N'Dağıtımda', N'Onaylandı',  NULL, '2026-10-02 10:00', N'Yetkili Mühendis'),
 (26, 6,  N'Onaylandı', N'Gaz Açıldı', NULL, '2026-10-05 16:00', N'Yetkili Mühendis'),
 -- Proje 7
 (27, 7,  NULL,        N'Çizimde',    NULL, '2026-09-23 10:00', N'Yetkili Mühendis'),
 (28, 7,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-09-25 10:00', N'Yetkili Mühendis'),
 -- Proje 8
 (29, 8,  NULL,        N'Çizimde',    NULL, '2026-10-14 10:00', N'Yetkili Mühendis'),
 -- Proje 9
 (30, 9,  NULL,        N'Çizimde',    NULL, '2026-10-05 10:00', N'Yetkili Mühendis'),
 (31, 9,  N'Çizimde',   N'Dağıtımda',  NULL, '2026-10-07 10:00', N'Yetkili Mühendis'),
 (32, 9,  N'Dağıtımda', N'Onaylandı',  NULL, '2026-10-21 10:00', N'Yetkili Mühendis'),
 -- Proje 10
 (33, 10, NULL,        N'Çizimde',    NULL, '2026-09-30 10:00', N'Yetkili Mühendis'),
 (34, 10, N'Çizimde',   N'Dağıtımda',  NULL, '2026-10-01 10:00', N'Yetkili Mühendis'),
 (35, 10, N'Dağıtımda', N'Ret',        N'Bina kolon projesi imza eksik', '2026-10-12 11:00', N'Yetkili Mühendis');
SET IDENTITY_INSERT PROJE_REVIZYON_LOG OFF;
GO

-- ---------------------------------------------------------------------
-- 4. KONTROL: tablo başına kayıt sayısı
-- ---------------------------------------------------------------------
SELECT N'MUSTERI' AS tablo, COUNT(*) AS kayit FROM MUSTERI
UNION ALL SELECT N'DAIRE',              COUNT(*) FROM DAIRE
UNION ALL SELECT N'KESIF',              COUNT(*) FROM KESIF
UNION ALL SELECT N'PROJE_DOSYASI',      COUNT(*) FROM PROJE_DOSYASI
UNION ALL SELECT N'RANDEVU',            COUNT(*) FROM RANDEVU
UNION ALL SELECT N'PROJE_REVIZYON_LOG', COUNT(*) FROM PROJE_REVIZYON_LOG;
GO