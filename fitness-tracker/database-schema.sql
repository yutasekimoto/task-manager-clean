-- 運動習慣トラッキングアプリ データベーススキーマ
-- Supabase PostgreSQL用

-- 1. 運動種目テーブル
CREATE TABLE exercises (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    steps TEXT DEFAULT '', -- 手順（JSON形式または改行区切り）
    video_url TEXT DEFAULT '', -- YouTubeなどの動画URL
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 曜日別スケジュールテーブル
CREATE TABLE schedules (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    day_of_week INTEGER NOT NULL, -- 0=日曜日, 1=月曜日, ..., 6=土曜日
    exercise_id INTEGER REFERENCES exercises(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. 日別運動記録テーブル
CREATE TABLE exercise_records (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    exercise_id INTEGER REFERENCES exercises(id) ON DELETE CASCADE,
    record_date DATE NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- インデックス作成（パフォーマンス向上）
CREATE INDEX idx_exercises_user_id ON exercises(user_id);
CREATE INDEX idx_schedules_user_id ON schedules(user_id);
CREATE INDEX idx_schedules_day_of_week ON schedules(day_of_week);
CREATE INDEX idx_exercise_records_user_id ON exercise_records(user_id);
CREATE INDEX idx_exercise_records_date ON exercise_records(record_date);
CREATE INDEX idx_exercise_records_user_date ON exercise_records(user_id, record_date);

-- Row Level Security (RLS) 設定
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_records ENABLE ROW LEVEL SECURITY;

-- RLSポリシー（ユーザーは自分のデータのみアクセス可能）
CREATE POLICY "Users can view own exercises" ON exercises
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can insert own exercises" ON exercises
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can update own exercises" ON exercises
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can delete own exercises" ON exercises
    FOR DELETE USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can view own schedules" ON schedules
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can insert own schedules" ON schedules
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can update own schedules" ON schedules
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can delete own schedules" ON schedules
    FOR DELETE USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can view own records" ON exercise_records
    FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can insert own records" ON exercise_records
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can update own records" ON exercise_records
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

CREATE POLICY "Users can delete own records" ON exercise_records
    FOR DELETE USING (user_id = current_setting('request.jwt.claims', true)::json->>'user_id');

-- 初期データ挿入用の関数（アプリから呼び出し）
CREATE OR REPLACE FUNCTION initialize_default_exercises(p_user_id TEXT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO exercises (user_id, name, description, order_index) VALUES
    (p_user_id, 'スクワット', '下半身を鍛える基本的な運動です。', 1),
    (p_user_id, '懸垂', '上半身（特に背筋）を鍛える運動です。', 2),
    (p_user_id, 'ダンベル上半身（プレス／ロー／レイズ）', 'ダンベルを使った上半身トレーニングです。', 3),
    (p_user_id, 'ランニング', '有酸素運動で心肺機能を向上させます。', 4),
    (p_user_id, 'ドローイング（朝）', '朝のドローイング（腹筋運動）です。', 5),
    (p_user_id, 'ドローイング（夜）', '夜のドローイング（腹筋運動）です。', 6);
END;
$$ LANGUAGE plpgsql;

-- 初期スケジュール設定用の関数
CREATE OR REPLACE FUNCTION initialize_default_schedule(p_user_id TEXT)
RETURNS VOID AS $$
DECLARE
    squat_id INTEGER;
    pullup_id INTEGER;
    dumbbell_id INTEGER;
    running_id INTEGER;
    drawing_morning_id INTEGER;
    drawing_evening_id INTEGER;
BEGIN
    -- 各運動のIDを取得
    SELECT id INTO squat_id FROM exercises WHERE user_id = p_user_id AND name = 'スクワット';
    SELECT id INTO pullup_id FROM exercises WHERE user_id = p_user_id AND name = '懸垂';
    SELECT id INTO dumbbell_id FROM exercises WHERE user_id = p_user_id AND name = 'ダンベル上半身（プレス／ロー／レイズ）';
    SELECT id INTO running_id FROM exercises WHERE user_id = p_user_id AND name = 'ランニング';
    SELECT id INTO drawing_morning_id FROM exercises WHERE user_id = p_user_id AND name = 'ドローイング（朝）';
    SELECT id INTO drawing_evening_id FROM exercises WHERE user_id = p_user_id AND name = 'ドローイング（夜）';

    -- スケジュール設定
    INSERT INTO schedules (user_id, day_of_week, exercise_id) VALUES
    -- 月曜日：懸垂、スクワット、ドローイング
    (p_user_id, 1, pullup_id),
    (p_user_id, 1, squat_id),
    (p_user_id, 1, drawing_morning_id),
    (p_user_id, 1, drawing_evening_id),
    
    -- 火曜日：ランニング、ドローイング
    (p_user_id, 2, running_id),
    (p_user_id, 2, drawing_morning_id),
    (p_user_id, 2, drawing_evening_id),
    
    -- 水曜日：ダンベル上半身、ドローイング
    (p_user_id, 3, dumbbell_id),
    (p_user_id, 3, drawing_morning_id),
    (p_user_id, 3, drawing_evening_id),
    
    -- 木曜日：懸垂、スクワット、ドローイング
    (p_user_id, 4, pullup_id),
    (p_user_id, 4, squat_id),
    (p_user_id, 4, drawing_morning_id),
    (p_user_id, 4, drawing_evening_id),
    
    -- 金曜日：ランニング、ドローイング
    (p_user_id, 5, running_id),
    (p_user_id, 5, drawing_morning_id),
    (p_user_id, 5, drawing_evening_id),
    
    -- 土曜日：スクワット、ドローイング
    (p_user_id, 6, squat_id),
    (p_user_id, 6, drawing_morning_id),
    (p_user_id, 6, drawing_evening_id),
    
    -- 日曜日：スクワット（やってもいいしやらなくてもいい）、ドローイング
    (p_user_id, 0, squat_id),
    (p_user_id, 0, drawing_morning_id),
    (p_user_id, 0, drawing_evening_id);
END;
$$ LANGUAGE plpgsql;

-- 実施率計算用のビュー
CREATE OR REPLACE VIEW exercise_stats AS
SELECT 
    er.user_id,
    e.name AS exercise_name,
    DATE_TRUNC('month', er.record_date) AS month,
    COUNT(*) AS scheduled_days,
    SUM(CASE WHEN er.completed THEN 1 ELSE 0 END) AS completed_days,
    ROUND(
        (SUM(CASE WHEN er.completed THEN 1 ELSE 0 END)::DECIMAL / COUNT(*)) * 100, 
        1
    ) AS completion_rate
FROM exercise_records er
JOIN exercises e ON er.exercise_id = e.id
GROUP BY er.user_id, e.name, DATE_TRUNC('month', er.record_date)
ORDER BY month DESC, exercise_name;