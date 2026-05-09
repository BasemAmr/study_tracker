import type { Goal } from '../domain';
import { createGoal, deleteGoal, getActiveGoals, getGoalById, listGoals, setGoalActive, updateGoal } from '../data/repositories';

export function normalizeGoal(goal: Goal): Goal {
  return { ...goal, name: goal.name.trim() };
}

export async function saveGoal(goal: Goal): Promise<number> {
  const normalized = normalizeGoal(goal);
  return normalized.id ? (await updateGoal(normalized), normalized.id) : createGoal(normalized);
}

export async function activateGoal(id: number): Promise<void> {
  await setGoalActive(id, true);
}

export async function deactivateGoal(id: number): Promise<void> {
  await setGoalActive(id, false);
}

export { createGoal, deleteGoal, getActiveGoals, getGoalById, listGoals, updateGoal };
