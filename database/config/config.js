import { SUPABASE_CONFIG as devConfig } from './config.dev.js';
import { SUPABASE_CONFIG as prodConfig } from './config.prod.js';
import { log } from '../../Logger.js';

const isDev = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';

log.debug(`Environment: ${isDev ? 'development' : 'production'}`);

export const SUPABASE_CONFIG = isDev ? devConfig : prodConfig;
