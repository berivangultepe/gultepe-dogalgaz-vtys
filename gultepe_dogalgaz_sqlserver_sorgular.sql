-- =====================================================================
-- Rapor (R1-R6) ve alt sorgu (K1-K7) kontrol sorguları - SQL Server
-- =====================================================================
USE GultepeDogalgaz;
GO
DECLARE @BaslangicTarihi DATE = '2026-08-01', @BitisTarihi DATE = '2026-12-31', @EsikTarih DATE = '2026-10-24', @MinKesifSayisi INT = 1;

-- R1 Dağıtım şirketi onay/ret özeti
SELECT p.DagitimSirketi,
       SUM(CASE WHEN l.YeniDurum = N'Onaylandı' THEN 1 ELSE 0 END) AS OnaySayisi,
       SUM(CASE WHEN l.YeniDurum = N'Ret'       THEN 1 ELSE 0 END) AS RetSayisi,
       ROUND(100.0 * SUM(CASE WHEN l.YeniDurum = N'Ret' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1) AS RetOraniYuzde
FROM PROJE_REVIZYON_LOG l
JOIN PROJE_DOSYASI p ON p.ProjeID = l.ProjeID
WHERE l.YeniDurum IN (N'Onaylandı', N'Ret')
  AND l.IslemTarihi BETWEEN @BaslangicTarihi AND @BitisTarihi
GROUP BY p.DagitimSirketi
ORDER BY RetOraniYuzde DESC;

-- R2 Cevap bekleyen projeler
SELECT p.DagitimSirketi, COUNT(*) AS BekleyenProje, MIN(p.BasvuruTarihi) AS EnEskiBasvuru
FROM PROJE_DOSYASI p
WHERE p.Durum = N'Dağıtımda' AND p.BasvuruTarihi <= @EsikTarih
GROUP BY p.DagitimSirketi
ORDER BY BekleyenProje DESC;

-- R3a Birden fazla kez reddedilen projeler
SELECT l.ProjeID, p.DagitimTakipNo, COUNT(*) AS RetSayisi, MAX(l.IslemTarihi) AS SonRetTarihi
FROM PROJE_REVIZYON_LOG l
JOIN PROJE_DOSYASI p ON p.ProjeID = l.ProjeID
WHERE l.YeniDurum = N'Ret'
GROUP BY l.ProjeID, p.DagitimTakipNo
HAVING COUNT(*) >= 2
ORDER BY RetSayisi DESC;

-- R3b En sık ret gerekçeleri
SELECT l.RetGerekcesi, COUNT(*) AS Adet
FROM PROJE_REVIZYON_LOG l
WHERE l.YeniDurum = N'Ret'
GROUP BY l.RetGerekcesi
ORDER BY Adet DESC;

-- R4 Teklif dönüşüm oranı
SELECT k.KombiTipi, COUNT(*) AS ToplamKesif,
       SUM(CASE WHEN k.TeklifDurumu = N'Kabul Edildi' THEN 1 ELSE 0 END) AS KabulSayisi,
       SUM(CASE WHEN k.TeklifDurumu = N'Reddedildi'   THEN 1 ELSE 0 END) AS RedSayisi,
       ROUND(100.0 * SUM(CASE WHEN k.TeklifDurumu = N'Kabul Edildi' THEN 1 ELSE 0 END) / COUNT(*), 1) AS KabulOraniYuzde,
       AVG(k.TahminiIsBedeli) AS OrtBedel
FROM KESIF k
WHERE k.KesifTarihi BETWEEN @BaslangicTarihi AND @BitisTarihi
GROUP BY k.KombiTipi
ORDER BY KabulOraniYuzde DESC;

-- R5 Bedel sapma raporu
SELECT k.KombiTipi, COUNT(*) AS KesifSayisi,
       SUM(CASE WHEN k.TahminiIsBedeli <> k.OnerilenBedel THEN 1 ELSE 0 END) AS ReviseEdilen,
       AVG(k.OnerilenBedel) AS OrtOnerilen, AVG(k.TahminiIsBedeli) AS OrtNihai,
       AVG((k.TahminiIsBedeli - k.OnerilenBedel) * 100.0 / k.OnerilenBedel) AS OrtSapmaYuzde
FROM KESIF k
WHERE k.OnerilenBedel > 0
GROUP BY k.KombiTipi
HAVING COUNT(*) >= @MinKesifSayisi;

-- R6 Aylık randevu özeti
SELECT YEAR(r.RandevuTarihSaat) AS Yil, MONTH(r.RandevuTarihSaat) AS Ay, r.RandevuTuru, r.Sonuc, COUNT(*) AS RandevuSayisi
FROM RANDEVU r
GROUP BY YEAR(r.RandevuTarihSaat), MONTH(r.RandevuTarihSaat), r.RandevuTuru, r.Sonuc
ORDER BY Yil, Ay, r.RandevuTuru;

-- K1 Kabul edilmiş ama proje dosyası açılmamış keşifler
SELECT k.KesifID, k.DaireID, k.KesifTarihi, k.TahminiIsBedeli
FROM KESIF k
WHERE k.TeklifDurumu = N'Kabul Edildi'
  AND NOT EXISTS (SELECT 1 FROM PROJE_DOSYASI p WHERE p.KesifID = k.KesifID);

-- K2 Onaylandığı halde gaz açım randevusu olmayan projeler
SELECT p.ProjeID, p.DagitimTakipNo, p.OnayTarihi
FROM PROJE_DOSYASI p
WHERE p.Durum = N'Onaylandı'
  AND NOT EXISTS (SELECT 1 FROM RANDEVU r
                  WHERE r.ProjeID = p.ProjeID AND r.RandevuTuru = N'Gaz Açım'
                    AND r.Sonuc IN (N'Bekliyor', N'Yapıldı'));

-- K3 Kendi kombi tipi ortalamasının üzerinde bedelli keşifler
SELECT k.KesifID, k.KombiTipi, k.TahminiIsBedeli
FROM KESIF k
WHERE k.TahminiIsBedeli > (SELECT AVG(k2.TahminiIsBedeli) FROM KESIF k2 WHERE k2.KombiTipi = k.KombiTipi)
ORDER BY k.KombiTipi, k.TahminiIsBedeli DESC;

-- K4 En az iki kez reddedilmiş ve hâlâ onaylanmamış projeler
SELECT p.ProjeID, p.DagitimTakipNo, p.Durum
FROM PROJE_DOSYASI p
WHERE p.Durum NOT IN (N'Onaylandı', N'Gaz Açıldı')
  AND p.ProjeID IN (SELECT l.ProjeID FROM PROJE_REVIZYON_LOG l
                    WHERE l.YeniDurum = N'Ret' GROUP BY l.ProjeID HAVING COUNT(*) >= 2);

-- K5 Her tesisat biriminin en son keşfi
SELECT d.DaireID, d.Adres, k.KesifID, k.KesifTarihi, k.TeklifDurumu
FROM DAIRE d
JOIN KESIF k ON k.DaireID = d.DaireID
WHERE k.KesifTarihi = (SELECT MAX(k2.KesifTarihi) FROM KESIF k2 WHERE k2.DaireID = d.DaireID);

-- K6 Birden fazla tesisat birimi olan müşterilerin kabul edilen iş toplamı
SELECT m.MusteriID, m.AdSoyad, COUNT(DISTINCT d.DaireID) AS TesisatBirimiSayisi, SUM(k.TahminiIsBedeli) AS KabulEdilenToplamBedel
FROM MUSTERI m
JOIN DAIRE d ON d.MusteriID = m.MusteriID
JOIN KESIF k ON k.DaireID = d.DaireID AND k.TeklifDurumu = N'Kabul Edildi'
GROUP BY m.MusteriID, m.AdSoyad
HAVING COUNT(DISTINCT d.DaireID) >= 2
ORDER BY KabulEdilenToplamBedel DESC;

-- K7 Çakışan aktif randevu tespiti
SELECT r.RandevuTarihSaat, COUNT(*) AS AktifRandevuSayisi
FROM RANDEVU r
WHERE r.Sonuc = N'Bekliyor'
GROUP BY r.RandevuTarihSaat
HAVING COUNT(*) > 1;
GO