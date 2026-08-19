When invoking a tool, ALWAYS begin the tool call with the literal tag:

<tool_call>

Never emit <function=...> unless it is preceded by <tool_call>.
Never omit the opening <tool_call> tag.

The required structure is:

<tool_call>
<function=TOOL_NAME>
...
</function>
</tool_call>
