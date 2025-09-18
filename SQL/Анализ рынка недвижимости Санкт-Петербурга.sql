/* Проект: Анализ рынка недвижимости Санкт-Петербурга
 * Автор: Фролова Дарья Михайловна
 * Дата: 25.02.2025
*/

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
 SELECT
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
     PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
 FROM real_estate.flats  
),
-- выведем значения, которые не содержат выбросы:
filtered_id AS(
 SELECT *
 FROM real_estate.flats AS f
 LEFT JOIN real_estate.advertisement AS a ON f.id=a.id
 LEFT JOIN real_estate.city AS c ON f.city_id=c.city_id
 LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
 WHERE
     total_area < (SELECT total_area_limit FROM limits)
     AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
     AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
     AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
     AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
--присвоим категорию Санкт-Петербург и ЛенОбл
city_category AS (
SELECT *,
CASE
	WHEN city='Санкт-Петербург'
	THEN 'Санкт-Петербург'
	ELSE 'ЛенОбл'
END AS city_category
FROM filtered_id
),
--Присваиваем категорию по количеству дней активности объявлений
days_exposition_category AS (
SELECT *,
CASE
	WHEN days_exposition>=1 AND days_exposition<=30
	THEN 'до месяца'
	WHEN days_exposition>=31 AND days_exposition<=90
	THEN 'до трех месяцев'
	WHEN days_exposition>=91 AND days_exposition<=180
	THEN 'до полгода'
	WHEN days_exposition>=181
	THEN 'более полугода'
	ELSE 'активные'
END AS days_exposition_category
FROM city_category
),
--узнаем стоимость одного квадратного метра и выводим только значения по городам
стоимость_1_метра_2 AS (
SELECT *,
last_price/total_area AS "стоимость 1 метра_2"
FROM days_exposition_category
WHERE type='город'
),
--считаем основные показатели
расчетные_показатели_1 AS  (
SELECT
city_category,
days_exposition_category,
count (*) AS "Количество объявлений",
count(*)/sum(count (*)) OVER (PARTITION BY city_category) AS "Доля объявлений",
avg("стоимость 1 метра_2") AS "avg стоимость 1 метра_2",
avg(total_area) AS "avg прощадь квартиры",
avg(ceiling_height) AS "avg высота потолка",
avg(kitchen_area) AS "avg площадь кухни",
avg(rooms) AS "avg количество комнат"
FROM стоимость_1_метра_2
GROUP BY city_category, days_exposition_category
),
--узнаем количество квартир студий
расчетные_показатели_2 AS  (
SELECT
city_category,
days_exposition_category,
count (rooms) AS "Количество квартир студий"
FROM стоимость_1_метра_2
WHERE rooms=0
GROUP BY city_category, days_exposition_category
)
--выводим основные показатели
SELECT
расчетные_показатели_1.city_category AS "Категория",
расчетные_показатели_1.days_exposition_category AS "Категория активности",
расчетные_показатели_1."Количество объявлений",
ROUND(расчетные_показатели_1."Доля объявлений",2) AS "Доля объявлений",
ROUND(расчетные_показатели_1."avg стоимость 1 метра_2"::numeric,2) AS "Стоимость 1м_2",
ROUND(расчетные_показатели_1."avg прощадь квартиры"::numeric,2) AS "Средняя прощадь квартиры",
ROUND(расчетные_показатели_1."avg высота потолка"::numeric,2) AS "Средняя высота потолка",
ROUND(расчетные_показатели_1."avg площадь кухни"::numeric,2) AS "Средняя площадь кухни",
ROUND(расчетные_показатели_1."avg количество комнат"::numeric,2) AS "Среднее количество комнат",
ROUND(расчетные_показатели_2."Количество квартир студий"::numeric/расчетные_показатели_1."Количество объявлений",4) AS "Доля квартир студий"
FROM расчетные_показатели_1
JOIN расчетные_показатели_2 ON расчетные_показатели_1.city_category=расчетные_показатели_2.city_category AND расчетные_показатели_1.days_exposition_category=расчетные_показатели_2.days_exposition_category
GROUP BY расчетные_показатели_1.city_category,
расчетные_показатели_1.days_exposition_category,
расчетные_показатели_1."Количество объявлений",
расчетные_показатели_1."Доля объявлений",
расчетные_показатели_1."avg стоимость 1 метра_2",
расчетные_показатели_1."avg прощадь квартиры",
расчетные_показатели_1."avg высота потолка",
расчетные_показатели_1."avg площадь кухни",
расчетные_показатели_1."avg количество комнат"::numeric,
расчетные_показатели_2."Количество квартир студий"
ORDER BY "Категория" DESC, "Количество объявлений";

-- Задача 2: Сезонность объявлений
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
 SELECT
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
     PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
     PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
 FROM real_estate.flats  
),
-- выведем итоговую таблицу, которая не содержит выбросы:
 filtered_id AS(
 SELECT 
 a.id,
 first_day_exposition,
 days_exposition,
 last_price,
 total_area,
 rooms,
 ceiling_height,
 floors_total,
 living_area,
 floor,
 is_apartment,
 open_plan,
 kitchen_area,
 balcony,
 airports_nearest,
 parks_around3000,
 ponds_around3000,
 c.city_id,
 city,
 t.type_id,
 type
 FROM real_estate.flats AS f
 LEFT JOIN real_estate.advertisement AS a ON f.id=a.id
 LEFT JOIN real_estate.city AS c ON f.city_id=c.city_id
 LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
 WHERE
     total_area < (SELECT total_area_limit FROM limits)
     AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
     AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
     AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
     AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
----выводим основные показатели
table_1 AS (
SELECT
id,
EXTRACT(MONTH FROM first_day_exposition) AS "месяц подачи объявления",
EXTRACT(MONTH FROM (first_day_exposition + INTERVAL '1 day' *  days_exposition)) AS "месяц снятия объявления",
last_price/total_area AS "стоимость квадратного метра",
total_area AS "площадь квартиры"
FROM filtered_id
),
-- считаем показатели при подаче объявления
table_2 AS (
SELECT
"месяц подачи объявления",
count (id) AS "количество объявлений",
rank() OVER (ORDER BY count (id) desc) AS "ранг подачи"
FROM table_1
GROUP BY "месяц подачи объявления"
),
--считаем показатели при снятии объявления
table_3 AS (
SELECT
"месяц снятия объявления",
count (id) AS "количество объявлений",
rank() OVER (ORDER BY count (id) desc) AS "ранг снятия"
FROM table_1
WHERE "месяц снятия объявления" IS NOT NULL
GROUP BY "месяц снятия объявления"
),
--считаем средние значения по стоимость 1-го квадратного метра и площади квартиры
table_4 AS (
SELECT
"месяц подачи объявления",
ROUND(avg("стоимость квадратного метра"::numeric),2) AS "средняя стоимость 1м_2",
ROUND(avg("площадь квартиры"::numeric),2) AS "средняя площадь квартиры"
FROM table_1
GROUP BY "месяц подачи объявления"
)
--выводим итоговую таблицу
SELECT
table_2."месяц подачи объявления",
table_2."количество объявлений",
table_2."ранг подачи",
"месяц снятия объявления",
table_3."количество объявлений",
table_3."ранг снятия",
"средняя стоимость 1м_2",
"средняя площадь квартиры"
FROM table_2
JOIN table_3 ON table_2."месяц подачи объявления"=table_3."месяц снятия объявления"
JOIN table_4 ON table_2."месяц подачи объявления"=table_4."месяц подачи объявления"
ORDER BY table_2."ранг подачи";

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
SELECT
    PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
    PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
    PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
    PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
    PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM real_estate.flats 
),
-- выведем необходимые значения, которые не содержат выбросы:
filtered_id AS(
SELECT
a.id,
c.city,
a.first_day_exposition,
a.days_exposition,
a.last_price,
f.total_area,
a.last_price::numeric/f.total_area AS "стоимость за 1м_2"
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement AS a ON f.id=a.id
LEFT JOIN real_estate.city AS c ON f.city_id=c.city_id
LEFT JOIN real_estate.type AS t ON f.type_id=t.type_id
WHERE
    total_area < (SELECT total_area_limit FROM limits)
    AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
    AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
    AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
    AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
--посчитаем необходимые значения
SELECT city AS "название населенного пункта",
count(id) AS "кол_во объявлений",
ROUND(SUM(CASE WHEN days_exposition IS NOT NULL THEN 1 ELSE 0 END)::numeric / COUNT(id), 4) AS "доля снятых объявлений",
ROUND(avg(days_exposition::numeric),2) AS "среднее время продажи",
ROUND(avg("стоимость за 1м_2"::numeric),0) AS "средняя стоимость 1м_2",
ROUND(avg(total_area::numeric),2) AS "средняя площадь квартиры"
FROM filtered_id
WHERE city<>'Санкт-Петербург'
GROUP BY city
ORDER BY "кол_во объявлений" DESC,
"доля снятых объявлений" DESC,
"среднее время продажи" DESC,
"средняя стоимость 1м_2" DESC,
"средняя площадь квартиры" DESC
LIMIT 15;


