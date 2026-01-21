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
            .select('*')
            .eq('date', dateString);
        if (error) throw error;
        log.debug(items);
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

                if (item.type_id === 1) {
                    itemDiv.innerHTML = `
                        <h3>${item.name}</h3>
                        <p>Цель: ${item.target_value} к ${item.end_date}</p>
                        <p>Сейчас: ${item.fact_value ?? 0} (${(item.completion ?? 0).toFixed(2)}%), темп: ${(item.pace ?? 0).toFixed(2)}%</p>
                        <input type="number" step="0.01" value="${item.value ?? ''}" placeholder="Введите значение" class="item-input" data-item-id="${item.item_id}">
                    `;
                } else {
                    itemDiv.innerHTML = `
                        <h3>${item.name}</h3>
                        <p>Цель: ${item.target_value} in ${item.interval_type}</p>
                        <p>Сегодня: ${(item.completion ?? 0).toFixed(2)}%, темп: ${(item.pace ?? 0).toFixed(2)}%</p>
                        <input type="number" step="0.01" value="${item.value ?? ''}" placeholder="Введите значение" class="item-input" data-item-id="${item.item_id}">
                    `;
                }

                // Add event listener to the input inside itemDiv
                const inputElement = itemDiv.querySelector('.item-input');
                inputElement.addEventListener('change', async (e) => {
                    const num = parseFloat(e.target.value);
                    const value = isNaN(num) ? null : num;
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
                value: value
            }, { onConflict: 'date,item_id' });
        if (error) throw error;
        log.out();
    }

    async insertNullRecordsForDate(date) {
        log.in();
        const dateString = date.toISOString().split('T')[0];
        const { error } = await this.authManager.supabase.rpc('insert_null_data_for_date', {
            selected_date: dateString
        });
        if (error) throw error;
        log.out();
    }



    async showItemsForDate(date) {
        log.in();
        this.itemsSection.classList.remove('hidden');
        await this.ensureUserProfile();
        try {
            await this.insertNullRecordsForDate(date);
            const items = await this.loadItemsForDate(date);
            this.renderItemsForDate(items, date);
        } catch (error) {
            this.itemsSection.innerHTML = '<p>Ошибка загрузки задач: ' + error.message + '</p>';
        }
        log.out();
    }
}
