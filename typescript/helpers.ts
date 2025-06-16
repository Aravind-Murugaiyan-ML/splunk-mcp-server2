export function formatEventsAsMarkdown(events: any[], query: string): string {
  if (!events || events.length === 0) {
    return `Query: ${query}\nNo events found.`;
  }

  // Get all unique keys from events
  const allKeys: string[] = [];
  const seenKeys = new Set<string>();
  
  for (const event of events) {
    for (const key of Object.keys(event)) {
      if (!seenKeys.has(key)) {
        allKeys.push(key);
        seenKeys.add(key);
      }
    }
  }

  // Build markdown table
  const lines: string[] = [
    `Query: ${query}`,
    `Found: ${events.length} events`,
    '',
  ];

  // Header
  const header = '| ' + allKeys.join(' | ') + ' |';
  const separator = '|' + allKeys.map(key => '-'.repeat(key.length + 2)).join('|') + '|';
  lines.push(header, separator);

  // Rows
  for (const event of events) {
    const rowValues: string[] = [];
    for (const key of allKeys) {
      let value = String(event[key] || '');
      // Escape pipe characters in values
      value = value.replace(/\|/g, '\\|');
      rowValues.push(value);
    }
    const row = '| ' + rowValues.join(' | ') + ' |';
    lines.push(row);
  }

  return lines.join('\n');
}

export function formatEventsAsCSV(events: any[], query: string): string {
  if (!events || events.length === 0) {
    return `# Query: ${query}\n# No events found`;
  }

  // Get all unique keys
  const allKeys: string[] = [];
  const seenKeys = new Set<string>();
  
  for (const event of events) {
    for (const key of Object.keys(event)) {
      if (!seenKeys.has(key)) {
        allKeys.push(key);
        seenKeys.add(key);
      }
    }
  }

  const lines: string[] = [
    `# Query: ${query}`,
    `# Events: ${events.length}`,
    '',
  ];

  // Header
  lines.push(allKeys.join(','));

  // Rows
  for (const event of events) {
    const rowValues: string[] = [];
    for (const key of allKeys) {
      let value = String(event[key] || '');
      // Escape quotes and handle commas
      if (value.includes(',') || value.includes('"') || value.includes('\n')) {
        value = '"' + value.replace(/"/g, '""') + '"';
      }
      rowValues.push(value);
    }
    lines.push(rowValues.join(','));
  }

  return lines.join('\n');
}

export function formatEventsAsSummary(events: any[], query: string, eventCount: number): string {
  const lines: string[] = [
    `Query: ${query}`,
    `Total events: ${eventCount}`,
  ];

  if (!events || events.length === 0) {
    lines.push('No events found.');
    return lines.join('\n');
  }

  // Analyze events
  if (events.length < eventCount) {
    lines.push(`Showing: First ${events.length} events`);
  }

  // Time range analysis if _time exists
  if (events.length > 0 && '_time' in events[0]) {
    const times = events
      .filter(e => e._time)
      .map(e => e._time);
    
    if (times.length > 0) {
      lines.push(`Time range: ${times[times.length - 1]} to ${times[0]}`);
    }
  }

  // Field analysis
  const allFields = new Set<string>();
  for (const event of events) {
    Object.keys(event).forEach(key => allFields.add(key));
  }

  lines.push(`Fields: ${Array.from(allFields).sort().join(', ')}`);

  // Value frequency analysis for common fields
  const commonFields = ['status', 'sourcetype', 'host', 'source'];
  
  for (const field of commonFields) {
    if (allFields.has(field)) {
      const values = events
        .filter(e => field in e)
        .map(e => String(e[field] || ''));
      
      if (values.length > 0) {
        const valueCounts: { [key: string]: number } = {};
        for (const v of values) {
          valueCounts[v] = (valueCounts[v] || 0) + 1;
        }
        
        const topValues = Object.entries(valueCounts)
          .sort(([, a], [, b]) => b - a)
          .slice(0, 3)
          .map(([value, count]) => `${value} (${count})`);
        
        lines.push(`${field.charAt(0).toUpperCase() + field.slice(1)} distribution: ${topValues.join(', ')}`);
      }
    }
  }

  // Sample events
  lines.push('\nFirst 3 events:');
  events.slice(0, 3).forEach((event, i) => {
    const eventStr = Object.entries(event)
      .map(([k, v]) => `${k}=${v}`)
      .join(' | ');
    lines.push(`Event ${i + 1}: ${eventStr}`);
  });

  return lines.join('\n');
}