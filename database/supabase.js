import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const isDev = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';

let SUPABASE_CONFIG;

if (isDev) {
    const { SUPABASE_CONFIG: devConfig } = await import('./config/config.dev.js');
    SUPABASE_CONFIG = devConfig;
} else {
    const { SUPABASE_CONFIG: prodConfig } = await import('./config/config.prod.js');
    SUPABASE_CONFIG = prodConfig;
}

// Экспортируем готовый клиент Supabase
export const supabase = createClient(SUPABASE_CONFIG.URL, SUPABASE_CONFIG.ANON_KEY);
