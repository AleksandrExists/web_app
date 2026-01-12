import { supabase } from './auth.js';
import { log } from './Logger.js';

export async function ensureUserProfile() {
    log.in();
    const { data: { user } } = await supabase.auth.getUser();
    log.debug({ user });
    if (user) {
        const { data: existingUser } = await supabase.from('users').select('id').single();
        log.debug(existingUser);
        if (!existingUser) {
            await supabase.from('users').insert({
                id: user.id,
                email: user.email
            });
        }
    }
    log.out();
}

export async function loadTasks() {
    log.in();
    const { data: tasks, error } = await supabase.from('tasks').select('*');
    if (error) throw error;
    log.out();
    return tasks;
}

export function renderTasks(tasks, tasksListElement) {
    log.in();
    tasksListElement.innerHTML = '';
    if (tasks.length === 0) {
        tasksListElement.innerHTML = '<p>У вас нет задач.</p>';
    } else {
        tasks.forEach(task => {
            const taskDiv = document.createElement('div');
            taskDiv.className = 'task';
            taskDiv.innerHTML = `
                <h3>${task.name}</h3>
                <p>Тип: ${task.type_id}</p>
                <p>Начальное значение: ${task.start_value}</p>
                <p>Целевое значение: ${task.target_value}</p>
                <p>Дата начала: ${task.begin_date}</p>
                <p>Дата окончания: ${task.end_date}</p>
            `;
            tasksListElement.appendChild(taskDiv);
        });
    }
    log.out();
}

export function showTasksSection(authSection, tasksSection) {
    log.in();
    authSection.classList.add('hidden');
    tasksSection.classList.remove('hidden');
    log.out();
}

export function hideTasksSection(authSection, tasksSection) {
    log.in();
    tasksSection.classList.add('hidden');
    authSection.classList.remove('hidden');
    log.out();
}

export async function showTasks(authSection, tasksSection, tasksListElement) {
    log.in();
    showTasksSection(authSection, tasksSection);
    await ensureUserProfile();
    try {
        const tasks = await loadTasks();
        renderTasks(tasks, tasksListElement);
    } catch (error) {
        tasksListElement.innerHTML = '<p>Ошибка загрузки задач: ' + error.message + '</p>';
    }
    log.out();
}
