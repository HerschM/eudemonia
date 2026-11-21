"""Tries a condensing, structured variant of the write turn. Usage: structured.py <thoughts.json> <ids,comma>"""
import json, sys
import syn

SYSTEM = (
    'You turn spoken thoughts into one organised written note. The thoughts were dictated by one person, in order, '
    'and transcribed by speech recognition.\n\n'
    'Write the note like this:\n'
    '- First line: a title of at most six words.\n'
    '- Then the content as short bullet points, grouped under a plain one-word or two-word heading when there is more than one topic.\n'
    '- Each bullet states one point in as few words as possible, in the first person.\n\n'
    'Rules:\n'
    '- Keep every fact: names, numbers, dates, times, places, items in lists, reasons, decisions, plans.\n'
    '- Leave out filler, repetition, false starts and remarks about the recording itself.\n'
    '- When the speaker corrects themselves, keep only the corrected version.\n'
    '- Add nothing that was not said. No advice, no summary sentence at the end.\n'
    '- Output only the note.')

T = {t['id']: t['text'] for t in json.load(open(sys.argv[1]))}
sel = [T[i] for i in sys.argv[2].split(',')]
user = 'Thoughts:\n' + '\n'.join(f'{i + 1}. {t}' for i, t in enumerate(sel)) + '\n\nWrite the note.'
words = sum(len(t.split()) for t in sel)
out, pin, pout, dt = syn.complete((SYSTEM, user), None, words + 96)
print(out.replace('</think>', '').strip()); print(f'--- input {words} words, output {len(out.split())} words')
