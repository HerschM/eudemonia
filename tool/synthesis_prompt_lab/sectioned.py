"""Middle path for a small model: keep the sentences, only group them under topic headings. Usage: sectioned.py <thoughts.json> <ids>"""
import json, sys
import syn

SYSTEM = (
    'You tidy spoken thoughts into a written note. The thoughts were dictated by one person and transcribed by speech recognition.\n\n'
    'Do it like this:\n'
    '- Split the content into topics. Start each topic with a heading line of one to three words, followed by the cleaned sentences about that topic.\n'
    '- Keep the speaker\'s own sentences and every fact. Only remove filler words, false starts, repetition and remarks about the recording itself.\n'
    '- When the speaker corrects themselves, keep only the corrected version.\n'
    '- Add nothing that was not said. Write in the first person.\n'
    '- Output only the note.')

T = {t['id']: t['text'] for t in json.load(open(sys.argv[1]))}
sel = [T[i] for i in sys.argv[2].split(',')]
user = 'Thoughts:\n' + '\n'.join(f'{i + 1}. {t}' for i, t in enumerate(sel)) + '\n\nWrite the note.'
words = sum(len(t.split()) for t in sel)
out, pin, pout, dt = syn.complete((SYSTEM, user), None, int(words * 1.6) + 96)
print(out.strip()); print(f'--- input {words} words, output {len(out.split())} words')
