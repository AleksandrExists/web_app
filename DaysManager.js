import { log } from './Logger.js';

export class DaysManager {
    constructor() {
        this.daysSection = document.getElementById('days-section');
    }

    showDays() {
        log.in();
        this.daysSection.classList.remove('hidden');
        // Добавить кнопки дней, если не добавлены
        if (this.daysSection.children.length === 0) {
            const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
            days.forEach(day => {
                const button = document.createElement('button');
                button.className = 'day-button';
                button.textContent = day;
                this.daysSection.appendChild(button);
            });
        }
        log.out();
    }

    hideDays() {
        log.in();
        this.daysSection.classList.add('hidden');
        log.out();
    }
}
