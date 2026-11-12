-- =====================================================================
-- Kısıt testleri (SQL Server): her ifadenin HATA vermesi beklenir.
-- Çalıştırma: SSMS'te tamamını çalıştırın; "Messages" sekmesinde 16 hata görünmelidir.
-- Her test ayrı batch'tir (GO), bu yüzden bir hata sonrakini engellemez.
-- Hata kodları: 2601 = benzersiz indeks, 547 = CHECK / FOREIGN KEY ihlali
-- =====================================================================
USE GultepeDogalgaz;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'--- T01 UNIQUE INDEX: tekrarlayan AboneNo';
INSERT INTO DAIRE (MusteriID, Adres, AboneNo) VALUES (1, N'Test adres', N'10000001');
GO
PRINT N'--- T02 CHECK: geçersiz TesisatTuru';
INSERT INTO DAIRE (MusteriID, Adres, TesisatTuru) VALUES (1, N'Test adres', N'Villa');
GO
PRINT N'--- T03 FK: olmayan müşteri';
INSERT INTO DAIRE (MusteriID, Adres) VALUES (999, N'Test adres');
GO
PRINT N'--- T04 CHECK: negatif petek metrajı';
INSERT INTO KESIF (DaireID, KesifTarihi, PetekMetraji, KombiTipi, TahminiIsBedeli)
VALUES (2, '2026-11-01', -5, N'Klasik', 10000);
GO
PRINT N'--- T05 CHECK: bedel öneriden farklı, revize nedeni boş';
INSERT INTO KESIF (DaireID, KesifTarihi, PetekMetraji, KombiTipi, OnerilenBedel, TahminiIsBedeli)
VALUES (2, '2026-11-01', 10, N'Klasik', 20500, 18000);
GO
PRINT N'--- T06 CHECK: geçersiz TeklifDurumu';
INSERT INTO KESIF (DaireID, KesifTarihi, PetekMetraji, KombiTipi, TahminiIsBedeli, TeklifDurumu)
VALUES (2, '2026-11-01', 10, N'Klasik', 20000, N'Beklemede');
GO
PRINT N'--- T07 UNIQUE: aynı keşfe ikinci proje dosyası';
INSERT INTO PROJE_DOSYASI (KesifID) VALUES (1);
GO
PRINT N'--- T08 CHECK: takip no ve başvuru tarihi olmadan Dağıtımda';
INSERT INTO PROJE_DOSYASI (KesifID, Durum) VALUES (11, N'Dağıtımda');
GO
PRINT N'--- T09 CHECK: onay tarihi başvuru tarihinden önce';
INSERT INTO PROJE_DOSYASI (KesifID, DagitimSirketi, DagitimTakipNo, Durum, BasvuruTarihi, OnayTarihi)
VALUES (11, N'Aksa', N'AKS-TEST-1', N'Onaylandı', '2026-10-20', '2026-10-10');
GO
PRINT N'--- T10 CHECK: Onaylandı durumunda onay tarihi boş';
INSERT INTO PROJE_DOSYASI (KesifID, DagitimSirketi, DagitimTakipNo, Durum, BasvuruTarihi)
VALUES (11, N'Aksa', N'AKS-TEST-2', N'Onaylandı', '2026-10-20');
GO
PRINT N'--- T11 CHECK: gaz açım randevusunda ProjeID boş';
INSERT INTO RANDEVU (DaireID, RandevuTuru, RandevuTarihSaat) VALUES (3, N'Gaz Açım', '2026-12-01 10:00');
GO
PRINT N'--- T12 UNIQUE INDEX: aynı tarih-saatte ikinci aktif randevu';
INSERT INTO RANDEVU (DaireID, RandevuTuru, RandevuTarihSaat) VALUES (4, N'Keşif', '2026-11-10 10:00');
GO
PRINT N'--- T13 CHECK: gerekçesiz ret logu';
INSERT INTO PROJE_REVIZYON_LOG (ProjeID, EskiDurum, YeniDurum, IslemYapan)
VALUES (5, N'Dağıtımda', N'Ret', N'Yetkili Mühendis');
GO
PRINT N'--- T14 CHECK: ret dışı geçişte gerekçe dolu';
INSERT INTO PROJE_REVIZYON_LOG (ProjeID, EskiDurum, YeniDurum, RetGerekcesi, IslemYapan)
VALUES (5, N'Dağıtımda', N'Onaylandı', N'Gerekçe olmamalı', N'Yetkili Mühendis');
GO
PRINT N'--- T15 FK: bağlı kaydı olan müşteriyi silme';
DELETE FROM MUSTERI WHERE MusteriID = 1;
GO
PRINT N'--- T16 FK: bağlı kaydı olan projeyi silme';
DELETE FROM PROJE_DOSYASI WHERE ProjeID = 1;
GO

PRINT N'--- KONTROL: kayıt sayıları değişmemeli (14, 16, 16, 10, 23, 35)';
SELECT (SELECT COUNT(*) FROM MUSTERI) AS musteri, (SELECT COUNT(*) FROM DAIRE) AS daire,
       (SELECT COUNT(*) FROM KESIF) AS kesif, (SELECT COUNT(*) FROM PROJE_DOSYASI) AS proje,
       (SELECT COUNT(*) FROM RANDEVU) AS randevu, (SELECT COUNT(*) FROM PROJE_REVIZYON_LOG) AS log_sayisi;
GO