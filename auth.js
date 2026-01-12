import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { SUPABASE_CONFIG } from './config.prod.js';
import { log } from './Logger.js';


export const supabase = createClient(SUPABASE_CONFIG.URL, SUPABASE_CONFIG.ANON_KEY);

export async function checkSession() {
    log.in();
    const { data: { session } } = await supabase.auth.getSession();
    log.debug(session);
    log.out();
    return session;
}

export function onAuthStateChange(callback) {
    log.in();
    log.debug('auth');
    log.debug('event: ' || event);
    log.debug('session:' || session);
    log.debug(callback);
    supabase.auth.onAuthStateChange((event, session) => {
        log.debug('supabase');
        log.debug('event: ' || event);
        log.debug('session:' || session);
        log.debug(callback);
        callback(event, session);
    });
    log.out();
}

export async function sendMagicLink(email) {
    log.in();
    const { error } = await supabase.auth.signInWithOtp({ email });
    if (error) throw error;
    log.out();
}

export function getCurrentUser() {
    log.in();
    log.out();
    return supabase.auth.getUser();
}

export async function logout() {
    log.in();
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    log.out();
}
