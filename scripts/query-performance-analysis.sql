-- 쿼리 성능 분석 도구 설정
-- pg_stat_statements 확장을 활용한 쿼리 성능 모니터링

-- 1. pg_stat_statements 확장 활성화
-- postgresql.conf 설정 필요: shared_preload_libraries = 'pg_stat_statements'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 2. 쿼리 성능 통계 조회
-- 가장 자주 실행되는 쿼리
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    max_time,
    rows
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 20;

-- 3. 가장 느린 쿼리 식별
-- 평균 실행 시간이 긴 쿼리
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    max_time,
    min_time,
    stddev_time
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_time DESC
LIMIT 20;

-- 4. 총 실행 시간이 긴 쿼리
-- 전체 시스템 성능에 영향이 큰 쿼리
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    (total_time / 1000 / 60) as total_minutes,
    rows
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 20;

-- 5. 쿼리 플랜 분석
-- 특정 쿼리의 실행 계획 분석
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)
SELECT 
    u.name,
    COUNT(o.id) as order_count,
    SUM(o.total_amount) as total_spent
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.status = 'ACTIVE'
    AND o.created_at >= '2024-01-01'
GROUP BY u.name
ORDER BY total_spent DESC
LIMIT 10;

-- 6. 느린 쿼리 로그 설정
-- postgresql.conf 설정:
-- log_min_duration_statement = 1000  (1초 이상 쿼리 로그)
-- log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

-- 7. 쿼리 성능 비교 뷰 생성
-- 시간 경과에 따른 쿼리 성능 변화 모니터링
CREATE OR REPLACE VIEW query_performance_trend AS
SELECT 
    queryid,
    query,
    calls,
    total_time,
    mean_time,
    rows,
    shared_blks_hit,
    shared_blks_read,
    local_blks_hit,
    local_blks_read,
    temp_blks_read,
    temp_blks_written
FROM pg_stat_statements
WHERE calls > 5
ORDER BY mean_time DESC;

-- 8. 버퍼 히트율 분석
-- 메모리 효율성 분석
SELECT 
    schemaname,
    tablename,
    heap_blks_read,
    heap_blks_hit,
    idx_blks_read,
    idx_blks_hit,
    CASE 
        WHEN heap_blks_read + heap_blks_hit > 0 
        THEN (heap_blks_hit::float / (heap_blks_read + heap_blks_hit)) * 100
        ELSE 0
    END as heap_hit_ratio,
    CASE 
        WHEN idx_blks_read + idx_blks_hit > 0 
        THEN (idx_blks_hit::float / (idx_blks_read + idx_blks_hit)) * 100
        ELSE 0
    END as index_hit_ratio
FROM pg_statio_user_tables
ORDER BY heap_hit_ratio ASC;

-- 9. 잠금 대기 분석
-- 잠금 경합 모니터링
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    waiting,
    query
FROM pg_stat_activity
WHERE waiting = true
ORDER BY query_start;

-- 10. 활성 세션 모니터링
-- 현재 실행 중인 쿼리 모니터링
SELECT 
    pid,
    now() - query_start as duration,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle'
    AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;

-- 11. 장기 실행 쿼리 식별
-- 5분 이상 실행 중인 쿼리
SELECT 
    pid,
    now() - query_start as duration,
    usename,
    application_name,
    state,
    query
FROM pg_stat_activity
WHERE now() - query_start > interval '5 minutes'
    AND state != 'idle'
ORDER BY duration DESC;

-- 12. 테이블 크기 및 행 수 분석
-- 테이블별 스토리지 사용량
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as indexes_size,
    n_live_tup as row_count,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 13. 쿼리 최적화를 위한 통계 정보
-- 컬럼 통계 정보 확인
SELECT 
    schemaname,
    tablename,
    attname as column_name,
    n_distinct as distinct_values,
    null_frac as null_fraction,
    avg_width as avg_column_width,
    correlation as column_correlation
FROM pg_stats
WHERE schemaname = 'public'
    AND tablename IN ('users', 'products', 'orders', 'order_items', 'product_reviews')
ORDER BY tablename, n_distinct DESC;

-- 14. 인덱스 사용 통계 상세 분석
-- 인덱스 효율성 상세 분석
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_blks_read,
    idx_blks_hit,
    CASE 
        WHEN idx_blks_read + idx_blks_hit > 0 
        THEN (idx_blks_hit::float / (idx_blks_read + idx_blks_hit)) * 100
        ELSE 0
    END as cache_hit_ratio
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- 15. 쿼리 성능 기준선 설정
-- 주요 쿼리의 성능 기준선 생성
CREATE TABLE IF NOT EXISTS query_baseline (
    id SERIAL PRIMARY KEY,
    query_id BIGINT,
    query_hash TEXT,
    query_sample TEXT,
    baseline_mean_time FLOAT,
    baseline_calls INTEGER,
    baseline_total_time FLOAT,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 16. 성능 저하 쿼리 식별
-- 기준선 대비 성능 저하 쿼리
SELECT 
    ps.queryid,
    SUBSTRING(ps.query, 1, 100) as query_sample,
    ps.calls,
    ps.mean_time,
    ps.total_time,
    qb.baseline_mean_time,
    (ps.mean_time - qb.baseline_mean_time) as time_diff,
    ((ps.mean_time - qb.baseline_mean_time) / qb.baseline_mean_time * 100) as performance_change_percent
FROM pg_stat_statements ps
LEFT JOIN query_baseline qb ON ps.queryid = qb.query_id
WHERE qb.baseline_mean_time IS NOT NULL
    AND ps.mean_time > qb.baseline_mean_time * 1.5  -- 50% 이상 성능 저하
ORDER BY performance_change_percent DESC;

-- 17. 실시간 성능 모니터링 뷰
CREATE OR REPLACE VIEW real_time_performance_monitor AS
SELECT 
    pid,
    now() - query_start as duration,
    usename,
    application_name,
    client_addr,
    state,
    waiting,
    query_start,
    state_change,
    SUBSTRING(query, 1, 200) as query_sample
FROM pg_stat_activity
WHERE state != 'idle'
    AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;

-- 18. 자동화된 성능 보고서 생성
-- 일일/주간 성능 보고서를 위한 쿼리
SELECT 
    DATE_TRUNC('day', query_start) as report_date,
    COUNT(*) as total_queries,
    AVG(EXTRACT(EPOCH FROM (now() - query_start))) as avg_query_duration,
    MAX(EXTRACT(EPOCH FROM (now() - query_start))) as max_query_duration,
    SUM(CASE WHEN state = 'active' THEN 1 ELSE 0 END) as active_queries,
    SUM(CASE WHEN waiting = true THEN 1 ELSE 0 END) as waiting_queries
FROM pg_stat_activity
WHERE query_start >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE_TRUNC('day', query_start)
ORDER BY report_date DESC;

-- 19. 쿼리 패턴 분석
-- 유사한 쿼리 패턴 식별
SELECT 
    REGEXP_REPLACE(query, '\d+', 'N') as query_pattern,
    COUNT(*) as pattern_count,
    AVG(mean_time) as avg_pattern_time,
    SUM(total_time) as total_pattern_time
FROM pg_stat_statements
WHERE calls > 10
GROUP BY REGEXP_REPLACE(query, '\d+', 'N')
ORDER BY pattern_count DESC
LIMIT 20;

-- 20. 성능 최적화 우선순위 계산
-- 쿼리 최적화 우선순위 산정
SELECT 
    queryid,
    SUBSTRING(query, 1, 100) as query_sample,
    calls as frequency,
    mean_time as avg_duration,
    total_time as total_duration,
    (calls * mean_time) as impact_score,
    CASE 
        WHEN calls > 1000 AND mean_time > 100 THEN 'CRITICAL'
        WHEN calls > 500 AND mean_time > 50 THEN 'HIGH'
        WHEN calls > 100 AND mean_time > 10 THEN 'MEDIUM'
        ELSE 'LOW'
    END as optimization_priority
FROM pg_stat_statements
WHERE calls > 10
ORDER BY impact_score DESC;
