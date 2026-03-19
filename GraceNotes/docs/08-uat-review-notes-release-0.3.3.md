## Grace Note Screen

### Refine chip display behavior

Current behavior:

- there are two types of summarizers, cloud summarizer and no summarizing.
- when cloud summarizer toggle is off, there is no summarizing for chip labels and the chip displays at most 10 unit chars (1 Han char = 2 units, 1 latin char = 1 unit). The sentnce is truncated and first 10 unit chars is used and there is a faded effect.
- when cloud summarizer toggle is on, cloud summarizer works in the background. when the cloud summarizer got a return, chip label updates.

The problem

- with cloud summarizer on, if the returned label exceeds 10 unit chars, the label is still truncated to at most 10 with a faded effect. Since the returned label is supposed to be a complete phrase, this truncation will make the label illegible in most cases.

Expected behavior:

- No fading effect. 
- with cloud summarizer on, no truncation happening; full chip label is displayed. But the app should specify LLMs return a short label (10 unit chars) in the prompt.
- with cloud summarizer off, 10 unit chars truncation still applies, but append a "..." at the end, and no fading effect.

### The completion badges (Daily Rhythm / Complete) should be clickable, displaying a short description of what the label means.

### More stylish completion status for each category

- Main idea: make "X of 5" at the bottom of the text input in each category five dots, with different color / fill / or other styles indicating different status.
- Make the 5 dots appear next to each section title, aligned to the right (debatable, could appear next to the section title), so it looks like:

```
Gratitudes            x x * o o
[chip 1] [chip 2] (+)
[Text input                   ]
```

- so there are three status: `*`, `x`, and `o`.
- `*` means editing
- `x` means edited
- `o` means to be edited

- of course, they should be stylized. The buttons should respond to the chip statuses.
- No more `x of 5` text


## Review Screen

### Icon consistency

- make the completion badge icons consistent between timeline and Grace Note screen. (Daily Rhythm icons are different)

## Settings Screen

### Need to harden the storage thing.

- We need to make iCloud syncing robust and reliable.
- Need to add input grace note data function.

### Combine AI toggles

- we can just combine `Use cloud summarization` and `Use AI review insights` toggles to one, called something like `AI features`. 
- Also need to include the ability to let users to BYOK. (API key, token, base url).

### Turn on notification buttons size

- when system notification is off, the Opne Settings button is way too big. 
