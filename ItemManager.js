import { log } from './Logger.js';

export class ItemManager {
    constructor(authManager) {
        this.authManager = authManager;
        this.itemsSection = document.getElementById('items-section');
    }

    async ensureUserProfile() {
        log.in();
        const { data: { user } } = await this.authManager.supabase.auth.getUser();
        log.debug({ user });
        if (user) {
            const { data: existingUser } = await this.authManager.supabase.from('users').select('id').single();
            log.debug(existingUser);
            if (!existingUser) {
                await this.authManager.supabase.from('users').insert({
                    id: user.id,
                    email: user.email
                });
            }
        }
        log.out();
    }

    async loadItemsForDate(date) {
        log.in();
        const dateString = date.toISOString().split('T')[0];
        const { data: items, error } = await this.authManager.supabase
            .from('days')
            .select('*');
            // .lte('begin_date', dateString)
            // .or(`end_date.is.null,end_date.gte.${dateString}`)
            // .or(`date.is.null,date.eq.${dateString}`);
        if (error) throw error;
        log.out();
        return items;
    }

    renderItemsForDate(items, date) {
        log.in();
        this.itemsSection.innerHTML = '';
        if (items.length === 0) {
            this.itemsSection.innerHTML = '<p>У вас нет задач на этот день.</p>';
        } else {
            items.forEach(item => {
                const itemDiv = document.createElement('div');
                itemDiv.className = 'item';

                const input = document.createElement('input');
                input.type = 'number';
                input.step = '0.01';
                input.value = item.value || '';
                input.placeholder = 'Введите значение';
                input.className = 'item-input';
                input.dataset.itemId = item.item_id;

                input.addEventListener('change', async (e) => {
                    const value = parseFloat(e.target.value) || null;
                    try {
                        await this.updateItemValue(date, item.item_id, value);
                        // Перезагрузить задачи для обновления расчетов
                        const updatedItems = await this.loadItemsForDate(date);
                        this.renderItemsForDate(updatedItems, date);
                    } catch (error) {
                        console.error('Ошибка сохранения:', error);
                        alert('Ошибка сохранения данных');
                    }
                });

                itemDiv.innerHTML = `
                    <h3>${item.name}</h3>
                    <p>Цель: ${item.target_value} к ${item.end_date}</p>
                    <p>Сейчас: ${item.fact_value}, темп: ${item.pace}%</p>
                `;
                itemDiv.appendChild(input);
                this.itemsSection.appendChild(itemDiv);
            });
        }
        log.out();
    }

    hideItemsSection() {
        log.in();
        this.itemsSection.classList.add('hidden');
        this.itemsSection.innerHTML = '';
        log.out();
    }

    async updateItemValue(date, itemId, value) {
        log.in();
        const dateString = date.toISOString().split('T')[0];
        const { error } = await this.authManager.supabase
            .from('data')
            .upsert({
                date: dateString,
                item_id: itemId,
                value: value || null
            }, { onConflict: 'date,item_id' });
        if (error) throw error;
        log.out();
    }

    async showItemsForDate(date) {
        log.in();
        this.itemsSection.classList.remove('hidden');
        await this.ensureUserProfile();
        try {
            const items = await this.loadItemsForDate(date);
            this.renderItemsForDate(items, date);
        } catch (error) {
            this.itemsSection.innerHTML = '<p>Ошибка загрузки задач: ' + error.message + '</p>';
        }
        log.out();
    }
}
