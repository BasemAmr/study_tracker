<script lang="ts">
  import { onMount } from 'svelte';
  import { toasts } from '@/core/stores/toastStore';
  import {
    saveSubject, deleteSubject, updateDifficulty,
    saveSubjectGroup, listSubjectGroups, deleteSubjectGroup,
    getGroupedSubjects
  } from '@/core/services/subjectService';
  import type { Subject, SubjectGroup, GroupedSubjects } from '@/core/domain';
  import Card from '@/ui/components/Card.svelte';
  import Button from '@/ui/components/Button.svelte';
  import Input from '@/ui/components/Input.svelte';
  import Select from '@/ui/components/Select.svelte';
  import {
    BookOpen, Plus, Trash2, ChevronDown, ChevronRight, FolderOpen
  } from 'lucide-svelte';

  let groupedSubjects: GroupedSubjects[] = $state([]);
  let allGroups: SubjectGroup[] = $state([]);
  let newSubjectName = $state('');
  let newSubjectColor = $state('#63946d');
  let newSubjectGroupId = $state('');
  let newGroupName = $state('');
  let newGroupColor = $state('#63946d');
  let expandedGroups = $state(new Set<number | 'ungrouped'>());

  onMount(async () => {
    await refreshSubjects();
  });

  async function refreshSubjects() {
    groupedSubjects = await getGroupedSubjects();
    allGroups = await listSubjectGroups();
    // Auto-expand all groups
    expandedGroups = new Set([...allGroups.map((g) => g.id!), 'ungrouped']);
  }

  async function addSubject() {
    if (!newSubjectName.trim()) {
      toasts.error('Subject name is required.');
      return;
    }
    try {
      await saveSubject({
        name: newSubjectName,
        color: newSubjectColor,
        groupId: newSubjectGroupId ? parseInt(newSubjectGroupId) : null
      });
      toasts.success(`Subject "${newSubjectName}" added!`);
      newSubjectName = '';
      newSubjectGroupId = '';
      await refreshSubjects();
    } catch (err: any) {
      toasts.error(err.message ?? 'Failed to add subject.');
    }
  }

  async function removeSubject(id: number) {
    if (!confirm('Delete this subject? Sessions will keep their data.')) return;
    try {
      await deleteSubject(id);
      toasts.success('Subject deleted.');
      await refreshSubjects();
    } catch {
      toasts.error('Failed to delete subject.');
    }
  }

  async function handleDifficultyChange(id: number, newDifficulty: number) {
    try {
      await updateDifficulty(id, newDifficulty);
      toasts.success('Subject difficulty updated.');
      await refreshSubjects();
    } catch (err: any) {
      toasts.error(err.message ?? 'Failed to update difficulty.');
    }
  }

  async function addGroup() {
    if (!newGroupName.trim()) {
      toasts.error('Group name is required.');
      return;
    }
    try {
      await saveSubjectGroup({ name: newGroupName, color: newGroupColor });
      toasts.success(`Group "${newGroupName}" created!`);
      newGroupName = '';
      await refreshSubjects();
    } catch (err: any) {
      toasts.error(err.message ?? 'Failed to create group.');
    }
  }

  async function removeGroup(id: number) {
    if (!confirm('Delete this group? Subjects will become ungrouped.')) return;
    try {
      await deleteSubjectGroup(id);
      toasts.success('Group deleted.');
      await refreshSubjects();
    } catch {
      toasts.error('Failed to delete group.');
    }
  }

  function toggleGroup(id: number | 'ungrouped') {
    const next = new Set(expandedGroups);
    next.has(id) ? next.delete(id) : next.add(id);
    expandedGroups = next;
  }
</script>

<div class="space-y-5">
  <!-- Subject Groups -->
  <Card>
    <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-4">
      <FolderOpen size={18} /> Subject Groups
    </h3>

    <!-- Add group -->
    <div class="flex gap-3 items-end mb-4">
      <div class="flex-1 max-w-xs">
        <Input label="New group" bind:value={newGroupName} placeholder="e.g., Term 1, Year 4" />
      </div>
      <div>
        <label for="new-group-color" class="block text-sm font-medium text-ink-700 mb-1.5">Color</label>
        <input
          id="new-group-color"
          type="color"
          bind:value={newGroupColor}
          class="h-10 w-10 rounded-lg border border-ink-200 cursor-pointer"
        />
      </div>
      <Button onclick={addGroup}>
        <Plus size={15} /> Add group
      </Button>
    </div>

    <!-- Existing groups -->
    {#if allGroups.length > 0}
      <div class="space-y-2 mb-6">
        {#each allGroups as group}
          <div class="flex items-center justify-between rounded-xl border border-ink-100 bg-[#fcfcfa] p-3">
            <div class="flex items-center gap-3">
              <div class="h-3 w-3 rounded-full" style="background-color: {group.color ?? '#63946d'}"></div>
              <FolderOpen size={14} class="text-ink-400" />
              <span class="text-sm font-medium text-ink-900">{group.name}</span>
            </div>
            <button
              class="text-ink-200 hover:text-red-500 transition-colors"
              onclick={() => group.id && removeGroup(group.id)}
              aria-label="Delete group"
            >
              <Trash2 size={14} />
            </button>
          </div>
        {/each}
      </div>
    {/if}
  </Card>

  <!-- Subjects -->
  <Card>
    <h3 class="flex items-center gap-2 text-base font-semibold text-ink-900 mb-4">
      <BookOpen size={18} /> Subjects
    </h3>

    <!-- Add subject -->
    <div class="flex flex-wrap gap-3 items-end mb-6">
      <div class="flex-1 min-w-[180px]">
        <Input label="New subject" bind:value={newSubjectName} placeholder="e.g., Mathematics" />
      </div>
      <div>
        <label for="new-subject-color" class="block text-sm font-medium text-ink-700 mb-1.5">Color</label>
        <input
          id="new-subject-color"
          type="color"
          bind:value={newSubjectColor}
          class="h-10 w-10 rounded-lg border border-ink-200 cursor-pointer"
        />
      </div>
      <div class="w-40">
        <Select
          label="Group"
          bind:value={newSubjectGroupId}
          options={[{ value: '', label: 'No group' }, ...allGroups.map((g) => ({ value: String(g.id), label: g.name }))]}
        />
      </div>
      <Button onclick={addSubject}>
        <Plus size={15} /> Add
      </Button>
    </div>

    <!-- Grouped subjects list -->
    {#each groupedSubjects as gs}
      {@const groupId = gs.group?.id ?? 'ungrouped'}
      {@const isExpanded = expandedGroups.has(groupId)}
      <div class="mb-3">
        <button
          class="flex w-full items-center gap-2 rounded-xl p-2 text-sm font-medium text-ink-700 hover:bg-ink-100/50 transition-colors"
          onclick={() => toggleGroup(groupId)}
        >
          {#if isExpanded}<ChevronDown size={14} />{:else}<ChevronRight size={14} />{/if}
          {#if gs.group}
            <div class="h-2.5 w-2.5 rounded-full" style="background-color: {gs.group.color ?? '#63946d'}"></div>
            {gs.group.name}
          {:else}
            Ungrouped
          {/if}
          <span class="ml-auto text-xs text-ink-400">{gs.subjects.length}</span>
        </button>

        {#if isExpanded}
          <div class="ml-4 space-y-1.5 mt-1">
            {#each gs.subjects as subject}
              <div class="flex items-center justify-between rounded-xl border border-ink-100 bg-white p-3">
                <div class="flex items-center gap-3">
                  <div class="h-3 w-3 rounded-full" style="background-color: {subject.color ?? '#63946d'}"></div>
                  <span class="text-sm font-medium text-ink-900">{subject.name}</span>
                </div>
                <div class="flex items-center gap-4">
                  <div class="flex items-center gap-2">
                    <span class="text-xs text-ink-500">Difficulty</span>
                    <select
                      value={subject.difficultyLevel ?? 3}
                      onchange={(e) => handleDifficultyChange(subject.id!, parseInt(e.currentTarget.value))}
                      class="rounded-lg border border-ink-200 bg-[#fcfcfa] px-2 py-1 text-xs text-ink-700 focus:border-moss-300 focus:outline-none focus:ring-1 focus:ring-moss-100"
                    >
                      <option value="1">1 - Trivial</option>
                      <option value="2">2 - Easy</option>
                      <option value="3">3 - Medium</option>
                      <option value="4">4 - Hard</option>
                      <option value="5">5 - Brutal</option>
                    </select>
                  </div>
                  <button
                    class="text-ink-200 hover:text-red-500 transition-colors"
                    onclick={() => subject.id && removeSubject(subject.id)}
                    aria-label="Delete subject"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            {/each}
            {#if gs.subjects.length === 0}
              <p class="text-xs text-ink-400 py-2 pl-2">No subjects in this group</p>
            {/if}
          </div>
        {/if}
      </div>
    {/each}
  </Card>
</div>
