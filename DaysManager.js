import { log } from './Logger.js';

export class DaysManager {
    constructor(onDaySelect) {
        this.daysSection = document.getElementById('days-section');
        this.onDaySelect = onDaySelect;
        this.selectedDate = null;
    }

    showDays() {
        log.in();
        this.daysSection.classList.remove('hidden');
        // Добавить кнопки дней, если не добавлены
        if (this.daysSection.children.length === 0) {
            this.generateDayButtons();
        }
        log.out();
    }

    generateDayButtons() {
        const today = new Date();
        const daysOfWeek = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

        for (let i = 6; i >= 0; i--) {
            const date = new Date(today);
            date.setDate(today.getDate() - i);
            const dayOfWeek = daysOfWeek[date.getDay()];
            const dayNumber = date.getDate();
            const buttonText = `${dayNumber} ${dayOfWeek}`;

            const button = document.createElement('button');
            button.className = 'day-button';
            button.textContent = buttonText;
            button.dataset.date = date.toISOString().split('T')[0]; // YYYY-MM-DD

            button.addEventListener('click', () => this.selectDay(date));

            this.daysSection.appendChild(button);
        }
    }

    selectDay(date) {
        log.in();
        this.selectedDate = date;
        this.updateSelectedButton();
        if (this.onDaySelect) {
            this.onDaySelect(date);
        }
        log.out();
    }

    updateSelectedButton() {
        const buttons = this.daysSection.querySelectorAll('.day-button');
        buttons.forEach(button => {
            const buttonDate = new Date(button.dataset.date);
            if (buttonDate.toDateString() === this.selectedDate.toDateString()) {
                button.classList.add('selected');
            } else {
                button.classList.remove('selected');
            }
        });
    }

    hideDays() {
        log.in();
        this.daysSection.classList.add('hidden');
        log.out();
    }
}
