import { supabase } from './database/supabase.js';
import { log } from './Logger.js';

export class AuthManager {
    constructor() {
        this.supabase = supabase;
    }

    async checkSession() {
        log.in();
        const { data: { session } } = await this.supabase.auth.getSession();
        log.debug(session);
        log.out();
        return session;
    }

    async onAuthStateChange(callback) {
        log.in();
        log.debug('auth');
        log.debug('event: ' || event);
        log.debug('session:' || session);
        log.debug(callback);
        this.supabase.auth.onAuthStateChange((event, session) => {
            log.debug('supabase');
            log.debug('event: ' || event);
            log.debug('session:' || session);
            log.debug(callback);
            callback(event, session);
        });
        log.out();
    }

    async sendMagicLink(email) {
        log.in();
        const { error } = await this.supabase.auth.signInWithOtp({ email });
        if (error) throw error;
        log.out();
    }

    async getCurrentUser() {
        log.in();
        const result = await this.supabase.auth.getUser();
        log.out();
        return result;
    }

    async logout() {
        log.in();
        const { error } = await this.supabase.auth.signOut();
        if (error) throw error;
        log.out();
    }
}
