import sys, json
import tkinter as tk
from tkinter import ttk

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()

if isinstance(d, dict):
    d = [d]
elif not isinstance(d, list) or not d:
    sys.exit()

cols = []
for row in d:
    if isinstance(row, dict):
        for k in row.keys():
            if k not in cols:
                cols.append(k)

root = tk.Tk()
root.title('Nushell GridView')
root.geometry('800x400')

frame = ttk.Frame(root)
frame.pack(expand=True, fill='both')

tree = ttk.Treeview(frame, columns=cols, show='headings')
vsb = ttk.Scrollbar(frame, orient='vertical', command=tree.yview)
hsb = ttk.Scrollbar(frame, orient='horizontal', command=tree.xview)
tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)

def sort_column(tv, col, reverse):
    l = [(tv.set(k, col), k) for k in tv.get_children('')]

    try:
        l.sort(key=lambda t: float(t[0]), reverse=reverse)
    except ValueError:
        l.sort(reverse=reverse)

    for index, (val, k) in enumerate(l):
        tv.move(k, '', index)

    tv.heading(col, command=lambda: sort_column(tv, col, not reverse))

for c in cols:
    tree.heading(c, text=str(c), command=lambda _c=c: sort_column(tree, _c, False))
    tree.column(c, width=120, minwidth=50, stretch=True)

for row in d:
    if isinstance(row, dict):
        values = [row.get(c, '') for c in cols]
        tree.insert('', 'end', values=values)

tree.grid(column=0, row=0, sticky='nsew')
vsb.grid(column=1, row=0, sticky='ns')
hsb.grid(column=0, row=1, sticky='ew')

frame.grid_columnconfigure(0, weight=1)
frame.grid_rowconfigure(0, weight=1)

root.mainloop()
