import type { Subject, SubjectGroup, GroupedSubjects } from '../domain';
import {
  createSubject, deleteSubject, getSubjectById, getSubjectByName,
  listSubjects, updateSubject, assignSubjectToGroup
} from '../data/repositories/subjectRepository';
import {
  createSubjectGroup, deleteSubjectGroup, listSubjectGroups, updateSubjectGroup
} from '../data/repositories/subjectGroupRepository';

export function normalizeSubject(subject: Subject): Subject {
  return { ...subject, name: subject.name.trim(), color: subject.color?.trim() || null };
}

export async function saveSubject(subject: Subject): Promise<number> {
  const normalized = normalizeSubject(subject);
  const existing = await getSubjectByName(normalized.name);
  if (existing && existing.id !== normalized.id) {
    throw new Error('Subject name must be unique.');
  }

  return normalized.id ? (await updateSubject(normalized), normalized.id) : createSubject(normalized);
}

export async function saveSubjectGroup(group: SubjectGroup): Promise<number> {
  return group.id
    ? (await updateSubjectGroup(group), group.id)
    : createSubjectGroup(group);
}

export async function moveSubjectToGroup(subjectId: number, groupId: number | null): Promise<void> {
  await assignSubjectToGroup(subjectId, groupId);
}

export async function getGroupedSubjects(): Promise<GroupedSubjects[]> {
  const [subjects, groups] = await Promise.all([
    listSubjects(),
    listSubjectGroups()
  ]);

  const result: GroupedSubjects[] = [];

  // Groups with their subjects
  for (const group of groups) {
    result.push({
      group,
      subjects: subjects.filter((s) => s.groupId === group.id)
    });
  }

  // Ungrouped subjects
  const ungrouped = subjects.filter((s) => !s.groupId);
  if (ungrouped.length > 0 || groups.length === 0) {
    result.push({
      group: null,
      subjects: ungrouped
    });
  }

  return result;
}

export {
  deleteSubject, getSubjectById, getSubjectByName,
  listSubjects, updateSubject,
  deleteSubjectGroup, listSubjectGroups
};
export { updateDifficulty } from '../data/repositories/subjectRepository';
