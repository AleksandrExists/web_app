import { supabase } from './database/supabase.js';
import { log } from './Logger.js';

export class AuthManager {
    constructor() {
        this.supabasePromise = supabase;
    }

    async getSupabase() {
        return await this.supabasePromise;
    }

    async checkSession() {
        log.in();
        const supabaseClient = await this.getSupabase();
        const { data: { session } } = await supabaseClient.auth.getSession();
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
        const supabaseClient = await this.getSupabase();
        supabaseClient.auth.onAuthStateChange((event, session) => {
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
        const supabaseClient = await this.getSupabase();
        const { error } = await supabaseClient.auth.signInWithOtp({ email });
        if (error) throw error;
        log.out();
    }

    async getCurrentUser() {
        log.in();
        const supabaseClient = await this.getSupabase();
        const result = await supabaseClient.auth.getUser();
        log.out();
        return result;
    }

    async logout() {
        log.in();
        const supabaseClient = await this.getSupabase();
        const { error } = await supabaseClient.auth.signOut();
        if (error) throw error;
        log.out();
    }
}
