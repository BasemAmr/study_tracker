<script lang="ts">
  import { onMount } from 'svelte';
  import { toasts } from '@/core/stores/toastStore';
  import { createStudySession } from '@/core/services/sessionService';
  import { listSubjects } from '@/core/services/subjectService';
  import { nowISO } from '@/core/utils/dateUtils';
  import type { Subject } from '@/core/domain';
  import Button from '@/ui/components/Button.svelte';
  import Input from '@/ui/components/Input.svelte';
  import Select from '@/ui/components/Select.svelte';
  import Modal from '@/ui/components/Modal.svelte';
  import { Save, FileText } from 'lucide-svelte';

  let {
    open = $bindable(false),
    onsaved
  }: {
    open?: boolean;
    onsaved?: () => void;
  } = $props();

  let subjects: Subject[] = $state([]);
  let date = $state(new Date().toISOString().split('T')[0]);
  let startTime = $state('09:00');
  let durationHours = $state('1');
  let durationMinutes = $state('0');
  let selectedSubjectId = $state('');
  let topic = $state('');
  let notes = $state('');
  let mood = $state('');
  let saving = $state(false);

  const moods = [
    { value: 'focused', label: 'Focused' },
    { value: 'productive', label: 'Productive' },
    { value: 'calm', label: 'Calm' },
    { value: 'tired', label: 'Tired' },
    { value: 'stressed', label: 'Stressed' },
    { value: 'distracted', label: 'Distracted' }
  ];

  onMount(async () => {
    subjects = await listSubjects();
  });

  async function handleSave() {
    const totalMinutes = parseInt(durationHours) * 60 + parseInt(durationMinutes);

    if (totalMinutes <= 0) {
      toasts.error('Duration must be greater than 0.');
      return;
    }

    if (!date) {
      toasts.error('Date is required.');
      return;
    }

    saving = true;

    try {
      const startAt = `${date}T${startTime}:00.000Z`;
      const endMinutes = parseInt(startTime.split(':')[0]) * 60 + parseInt(startTime.split(':')[1]) + totalMinutes;
      const endHour = Math.floor(endMinutes / 60) % 24;
      const endMin = endMinutes % 60;
      const endAt = `${date}T${String(endHour).padStart(2, '0')}:${String(endMin).padStart(2, '0')}:00.000Z`;

      const subject = subjects.find((s) => String(s.id) === selectedSubjectId);

      await createStudySession({
        startAt,
        endAt,
        durationMinutes: totalMinutes,
        subjectId: subject?.id ?? null,
        subjectName: subject?.name ?? null,
        topic: topic || null,
        mood: mood || null,
        notes: notes || null,
        mode: 'manual',
        breakMinutes: 0
      });

      toasts.success('Session logged successfully!');
      resetForm();
      open = false;
      onsaved?.();
    } catch (err) {
      toasts.error('Failed to save session.');
      console.error(err);
    } finally {
      saving = false;
    }
  }

  function resetForm() {
    date = new Date().toISOString().split('T')[0];
    startTime = '09:00';
    durationHours = '1';
    durationMinutes = '0';
    selectedSubjectId = '';
    topic = '';
    notes = '';
    mood = '';
  }
</script>

<Modal bind:open title="Manual Session Log">
  <div class="space-y-4">
    <div class="grid grid-cols-2 gap-4">
      <Input label="Date" type="date" bind:value={date} />
      <Input label="Start time" type="time" bind:value={startTime} />
    </div>

    <div class="grid grid-cols-2 gap-4">
      <Input label="Hours" type="number" bind:value={durationHours} placeholder="0" />
      <Input label="Minutes" type="number" bind:value={durationMinutes} placeholder="0" />
    </div>

    <Select
      label="Subject"
      bind:value={selectedSubjectId}
      options={subjects.map((s) => ({ value: String(s.id), label: s.name }))}
      placeholder="Select subject..."
    />

    <Input label="Topic" bind:value={topic} placeholder="e.g., Chapter 5 - Derivatives" />

    <Select
      label="Mood"
      bind:value={mood}
      options={moods}
      placeholder="How are you feeling?"
    />

    <Input label="Notes" type="textarea" bind:value={notes} placeholder="Session notes..." />

    <div class="flex justify-end gap-3 pt-2">
      <Button variant="secondary" onclick={() => (open = false)}>Cancel</Button>
      <Button onclick={handleSave} disabled={saving}>
        <Save size={15} /> {saving ? 'Saving...' : 'Save session'}
      </Button>
    </div>
  </div>
</Modal>
