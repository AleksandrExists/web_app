import { log } from './Logger.js';

export class DayInfoManager {
    constructor(authManager) {
        this.authManager = authManager;
        this.dayInfoSection = document.getElementById('day-info-section');
    }

    async loadDayStats(date) {
        log.in();
        const dateString = date.toISOString().split('T')[0];
        const { data: stats, error } = await this.authManager.supabase
            .from('day_stats')
            .select('*')
            .eq('date', dateString);
        if (error) {
            log.debug('Error loading stats:', error);
            log.out();
            return null;
        }
        if (stats.length === 0) {
            log.debug('No stats for date:', dateString);
            log.out();
            return null;
        }
        log.debug(stats[0]);
        log.out();
        return stats[0];
    }

    renderDayInfo(stats, date) {
        log.in();
        this.dayInfoSection.innerHTML = '';
        if (stats) {
            const infoDiv = document.createElement('div');
            infoDiv.className = 'day-info';
            infoDiv.innerHTML = `
                <p>Темп: ${(stats.weighted_pace ?? 0).toFixed(2)}%</p>
                <p>Рост: ${(stats.day_result ?? 0).toFixed(2)}%</p>
            `;
            this.dayInfoSection.appendChild(infoDiv);
        } else {
            this.dayInfoSection.innerHTML = '<p>Нет данных для этого дня.</p>';
        }
        log.out();
    }

    hideDayInfo() {
        log.in();
        this.dayInfoSection.classList.add('hidden');
        this.dayInfoSection.innerHTML = '';
        log.out();
    }

    async showDayInfo(date) {
        log.in();
        this.dayInfoSection.classList.remove('hidden');
        try {
            const stats = await this.loadDayStats(date);
            this.renderDayInfo(stats, date);
        } catch (error) {
            this.dayInfoSection.innerHTML = '<p>Ошибка загрузки статистики дня: ' + error.message + '</p>';
        }
        log.out();
    }
}
