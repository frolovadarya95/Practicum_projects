/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Фролова Дарья Михайловна
 * Дата: 10.02.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
--WITH count AS (
--SELECT 
--COUNT(id) AS count_id, (
	--SELECT COUNT(payer) AS count_payer
	--FROM fantasy.users
	--WHERE payer=1
	--)
--FROM fantasy.users
--)
--SELECT *,
--ROUND((count_payer::numeric/count_id),2) AS share
--FROM count;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
--WITH table_1 AS (
--SELECT 
--race,
--COUNT(payer) AS count_payer
--FROM fantasy.users
--JOIN fantasy.race USING(race_id)
--WHERE payer=1
--GROUP BY race
--),
--table_2 AS (
--SELECT 
--race,
--COUNT(id) AS count_id
--FROM fantasy.users
--JOIN fantasy.race USING(race_id)
--GROUP BY race
--)
--SELECT *,
--ROUND((count_payer::numeric/count_id),2) AS share
--FROM table_1
--JOIN table_2 USING (race);

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
--SELECT 
--COUNT(transaction_id ) AS count_id,
--SUM(amount) AS sum_amount,
--MIN(amount) AS min_amount,
--MAX(amount) AS max_amount,
--AVG(amount) AS avg_amount,
--PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median,
--STDDEV(amount) AS stand_dev
--FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
--WITH table_1 AS (
--SELECT 
--COUNT(transaction_id) AS count_id, (
--SELECT
--COUNT(amount) AS count_amount
--FROM fantasy.events
--WHERE amount=0
--)
--FROM fantasy.events
--)
--SELECT *,
--count_amount::NUMERIC/count_id AS share
--FROM table_1;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
--SELECT 
--CASE
	--WHEN u.payer=1
	--THEN 'Платящие'
	--ELSE 'Неплатящие'
--END AS catecory,
--COUNT(DISTINCT u.id) AS kol_vo_igrokov, --общее количество игроков
--COUNT(e.transaction_id)/COUNT(DISTINCT u.id) AS avg_cl_pokupok, -- среднее количество покупок
--ROUND(SUM(e.amount)::numeric/COUNT(DISTINCT u.id),2) AS avg_ct_pokupok -- среднюю суммарную стоимость покупок на одного игрока
--FROM fantasy.users AS u
--LEFT JOIN fantasy.events AS e ON u.id=e.id
--WHERE e.amount>0 
--GROUP BY catecory;

-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь:
--WITH table_1 AS (
--SELECT i.game_items, --выделяем группы эпических предметов 
--COUNT(DISTINCT e.id) AS kolvo_igrokov, -- считаем кол-во уникальных игроков
--COUNT(e.amount) AS absolut_kolvo_pokupok -- считаем кол-во абсолютное кол-во покупок
--FROM fantasy.items AS i
--LEFT JOIN fantasy.events AS e ON i.item_code=e.item_code
--WHERE e.amount>0
--GROUP BY i.game_items
--),
--table_2 AS (
--SELECT *,
--SUM(absolut_kolvo_pokupok) OVER () AS obshee_kolvo_pokupok --считаем общее кол-во покупок
--FROM table_1
--),
--table_3 AS (
--SELECT *,
--absolut_kolvo_pokupok/obshee_kolvo_pokupok AS otnosit_kolvo_pokupok, -- считаем относительное кол-во покупок
--kolvo_igrokov::numeric/(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount>0) AS doly_igrocov  -- считаем долю игроков от общего кол-ва покупок
--FROM table_2
--)
--SELECT 
--game_items,
--absolut_kolvo_pokupok,
--otnosit_kolvo_pokupok,
--doly_igrocov
--FROM table_3
--ORDER BY absolut_kolvo_pokupok DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH table_1 AS (
SELECT 
race,
COUNT(id) AS count_id--общее кол-во зарегестрированных игроков
FROM fantasy.race
JOIN fantasy.users USING(race_id)
GROUP BY race
),
table_2 AS (
SELECT
race,
COUNT(DISTINCT id) AS count_id_amount,-- кол-во игроков которые совершают покупки
COUNT(transaction_id) count_transaction_id, -- кол-во покупок
SUM(amount) AS sum_amount -- общая сумма покупок
FROM fantasy.events
JOIN fantasy.users USING (id)
JOIN fantasy.race USING (race_id)
WHERE amount>0
GROUP BY race
),
table_3 AS (
SELECT 
race,
ROUND(AVG(payer),2) AS fraction_amount -- доля платящих покупателей
FROM fantasy.race
JOIN fantasy.users USING(race_id)
WHERE id IN (SELECT id FROM fantasy.events WHERE amount>0)
GROUP BY race
) 
SELECT 
race,
count_id,--общее кол-во зарегестрированных игроков
count_id_amount,-- кол-во игроков которые совершают покупки
ROUND(count_id_amount::numeric/count_id,2) AS fraction_payer,--доля игроков кот.совершают покупки от общего количества игроков
fraction_amount, -- доля платящих игроков
ROUND(count_transaction_id::numeric/count_id_amount,2) AS avg_number_transaction_id, -- среднее кол-во покупок на одного игрока
ROUND(sum_amount::numeric/count_transaction_id,2) AS avg_number_amount, -- средняя стоимость одной покупки на одного игрока
ROUND(sum_amount::numeric/count_id_amount,2) AS avg_sum_amount -- средняя суммарнна стоимость всех покупок на одного игрока
FROM table_1
JOIN table_2 USING (race)
JOIN table_3 USING (race)
GROUP BY race, count_id, count_id_amount, count_transaction_id, sum_amount, fraction_amount
-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь









