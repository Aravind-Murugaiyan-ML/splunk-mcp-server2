/**
 * SPL query validation and output sanitization functions.
 */

export interface ValidationContext {
  safe_timerange: string;
  query_lower: string;
}

export type RiskScore = number | [number, number, number];
export type ValidationResult = number | [number, string];

// Helper functions for complex validation rules

export function checkCollectParams(query: string, context: ValidationContext, baseRisk: RiskScore): number {
  /**
   * Check for risky collect parameters.
   */
  if (/\|\s*collect\b/.test(context.query_lower)) {
    if (context.query_lower.includes('override=true') || context.query_lower.includes('addtime=false')) {
      return typeof baseRisk === 'number' ? baseRisk : baseRisk[0];
    }
  }
  return 0;
}

export function checkOutputlookupParams(query: string, context: ValidationContext, baseRisk: RiskScore): number {
  /**
   * Check for risky outputlookup parameters.
   */
  if (/\|\s*outputlookup\b/.test(context.query_lower)) {
    if (context.query_lower.includes('override=true')) {
      return typeof baseRisk === 'number' ? baseRisk : baseRisk[0];
    }
  }
  return 0;
}

export function parseTimeToHours(timeStr: string): number {
  /**
   * Convert Splunk time string to hours.
   */
  let time = timeStr.trim().toLowerCase();
  
  // Remove leading minus sign if present
  if (time.startsWith('-')) {
    time = time.substring(1);
  }
  
  // Handle relative time modifiers
  const match = time.match(/^(\d+)([smhdwmonqy]+)?(@[smhdwmonqy]+)?$/);
  if (match) {
    const value = parseInt(match[1]);
    const unit = match[2] || 's';
    
    // Convert to hours
    const multipliers: Record<string, number> = {
      's': 1/3600,      // seconds to hours
      'm': 1/60,        // minutes to hours
      'h': 1,           // hours
      'd': 24,          // days to hours
      'w': 24*7,        // weeks to hours
      'mon': 24*30,     // months to hours (approximate)
      'q': 24*90,       // quarters to hours (approximate)
      'y': 24*365       // years to hours
    };
    
    return value * (multipliers[unit] || 1);
  }
  
  // Handle special keywords
  if (['0', 'all', 'alltime'].includes(time)) {
    return Infinity; // All time
  }
  
  // Default to 24 hours if unparseable
  return 24;
}

export function checkTimeRange(query: string, context: ValidationContext, baseRisk: RiskScore): ValidationResult {
  /**
   * Check time range issues.
   * 
   * baseRisk can be:
   * - number: single risk score
   * - tuple: [no_risk, exceeds_safe_range, all_time/no_time]
   * 
   * Returns:
   * - number: risk score
   * - OR tuple: [risk_score, time_range_type] where time_range_type is 'all_time', 'exceeds_safe', or 'no_time'
   */
  let noRisk: number, exceedsSafe: number, allTime: number;
  
  if (Array.isArray(baseRisk)) {
    [noRisk, exceedsSafe, allTime] = baseRisk;
  } else {
    // Backward compatibility
    noRisk = 0;
    exceedsSafe = Math.floor(baseRisk * 0.5);
    allTime = baseRisk;
  }
  
  const queryLower = context.query_lower;
  const safeTimerangeStr = context.safe_timerange || '24h';
  const safeHours = parseTimeToHours(safeTimerangeStr);
  
  const hasEarliest = queryLower.includes('earliest') || queryLower.includes('earliest_time');
  const hasLatest = queryLower.includes('latest') || queryLower.includes('latest_time');
  const hasTimeRange = hasEarliest || hasLatest;
  
  if (!hasTimeRange) {
    // Check if it's an all-time search
    if (/all\s*time|alltime/.test(queryLower)) {
      return [allTime, 'all_time'];
    } else {
      // No time range specified, could default to all-time
      return [allTime, 'no_time'];
    }
  } else {
    // Extract time range from query
    const earliestMatch = queryLower.match(/earliest(?:_time)?\s*=\s*([^\s,]+)/);
    
    if (earliestMatch) {
      const timeValue = earliestMatch[1];
      const queryHours = parseTimeToHours(timeValue);
      
      // Check if it's all time (0 or inf)
      if (queryHours === Infinity || timeValue === '0') {
        return [allTime, 'all_time'];
      }
      
      // Check if time range exceeds safe range
      if (queryHours > safeHours) {
        return [exceedsSafe, 'exceeds_safe'];
      }
    }
  }
  
  return noRisk;
}

export function checkIndexUsage(query: string, context: ValidationContext, baseRisk: RiskScore): number {
  /**
   * Check for index usage patterns.
   * 
   * baseRisk can be:
   * - number: single risk score
   * - tuple: [no_risk, no_index_with_constraints, index_star_unconstrained]
   */
  let noRisk: number, noIndexConstrained: number, indexStar: number;
  
  if (Array.isArray(baseRisk)) {
    [noRisk, noIndexConstrained, indexStar] = baseRisk;
  } else {
    // Backward compatibility
    noRisk = 0;
    noIndexConstrained = Math.floor(baseRisk * 0.57); // ~20/35
    indexStar = baseRisk;
  }
  
  const queryLower = context.query_lower;
  
  if (queryLower.includes('index=*')) {
    // Check if there are constraining source/sourcetype
    if (!/source\s*=/.test(queryLower) && !/sourcetype\s*=/.test(queryLower)) {
      return indexStar; // Full risk for unconstrained index=*
    }
  } else if (!/index\s*=/.test(queryLower)) {
    // No index specified
    if (/source\s*=|sourcetype\s*=/.test(queryLower)) {
      return noIndexConstrained;
    }
  }
  return noRisk;
}

export function checkSubsearchLimits(query: string, context: ValidationContext, baseRisk: RiskScore): number {
  /**
   * Check for subsearches without limits.
   */
  const risk = typeof baseRisk === 'number' ? baseRisk : baseRisk[0];
  
  if (query.includes('[') && query.includes(']')) {
    const subsearchStart = query.indexOf('[');
    const subsearchEnd = query.indexOf(']') + 1;
    const subsearch = query.substring(subsearchStart, subsearchEnd).toLowerCase();
    
    if (!subsearch.includes('maxout') && !subsearch.includes('maxresults')) {
      return risk;
    }
  }
  return 0;
}

export function checkExpensiveCommands(query: string, context: ValidationContext, baseRisk: RiskScore): number {
  /**
   * Check for expensive commands and return appropriate score.
   */
  const risk = typeof baseRisk === 'number' ? baseRisk : baseRisk[0];
  const queryLower = context.query_lower;
  let multiplier = 0;
  
  // Check each expensive command (each adds to the multiplier)
  if (/\|\s*transaction\b/.test(queryLower)) {
    multiplier += 1;
  }
  if (/\|\s*map\b/.test(queryLower)) {
    multiplier += 1;
  }
  if (/\|\s*join\b/.test(queryLower)) {
    multiplier += 1;
  }
  
  return Math.floor(risk * multiplier);
}

export function checkAppendOperations(query: string, context: ValidationContext, baseRisk: RiskScore): number {
  /**
   * Check for append operations.
   */
  const risk = typeof baseRisk === 'number' ? baseRisk : baseRisk[0];
  
  if (/\|\s*(append|appendcols)\b/.test(context.query_lower)) {
    return risk;
  }
  return 0;
}

// ===========================================================================
export function validateSplQuery(query: string, safeTimerange: string): [number, string] {
  /**
   * Validate SPL query and calculate risk score using rule-based system.
   * 
   * Args:
   *     query: The SPL query to validate
   *     safeTimerange: Safe time range from configuration
   *     
   * Returns:
   *     Tuple of [risk_score, risk_message]
   */
  // Import here to avoid circular dependency
  const splRiskRules = require('./splRiskRules');
  const SPL_RISK_RULES = splRiskRules.SPL_RISK_RULES;
  
  let riskScore = 0;
  const issues: string[] = [];
  const queryLower = query.toLowerCase();
  
  // Context for function-based rules
  const context: ValidationContext = {
    safe_timerange: safeTimerange,
    query_lower: queryLower
  };
  
  // Process all rules
  for (const rule of SPL_RISK_RULES) {
    const [patternOrFunc, baseScore, message] = rule;
    
    if (typeof patternOrFunc === 'function') {
      // It's a function - call it with baseScore
      const result = patternOrFunc(query, context, baseScore);
      
      // Handle special case where function returns [score, type] tuple
      if (Array.isArray(result) && result.length === 2 && typeof result[1] === 'string') {
        const [score, timeType] = result;
        if (score > 0) {
          riskScore += score;
          // Special handling for time range messages
          if (patternOrFunc.name === 'checkTimeRange') {
            let formattedMessage: string;
            if (timeType === 'all_time') {
              formattedMessage = `All-time search detected (+${score}). This can be very resource intensive. Add time constraints like earliest=-24h latest=now to limit search scope.`;
            } else if (timeType === 'exceeds_safe') {
              formattedMessage = `Time range exceeds safe limit (+${score}). Consider narrowing your search window for better performance.`;
            } else if (timeType === 'no_time') {
              formattedMessage = `No time range specified (+${score}). Query may default to all-time. Add explicit time constraints like earliest=-24h latest=now.`;
            } else {
              formattedMessage = message.replace('{score}', score.toString());
            }
            issues.push(formattedMessage);
          } else {
            issues.push(message.replace('{score}', score.toString()));
          }
        }
      } else {
        // Regular number score
        const score = typeof result === 'number' ? result : 0;
        if (score > 0) {
          riskScore += score;
          // Format message with actual score
          issues.push(message.replace('{score}', score.toString()));
        }
      }
    } else {
      // It's a regex pattern
      if (new RegExp(patternOrFunc).test(queryLower)) {
        const score = typeof baseScore === 'number' ? baseScore : baseScore[0];
        riskScore += score;
        // Format message with base score
        issues.push(message.replace('{score}', score.toString()));
      }
    }
  }
  
  // Cap risk score at 100
  riskScore = Math.min(riskScore, 100);
  
  // Build final message
  if (issues.length === 0) {
    return [riskScore, "Query appears safe."];
  } else {
    let riskMessage = "Risk factors found:\n" + issues.map(issue => `- ${issue}`).join('\n');
    
    // Add high-risk warning if needed
    if (riskScore >= 50) {
      riskMessage += "\n\nConsider reviewing this query with your Splunk administrator.";
    }
    
    return [riskScore, riskMessage];
  }
}
// ===========================================================================

// ===========================================================================
export function sanitizeOutput(data: any): any {
  /**
   * Recursively sanitize sensitive data in output.
   * 
   * Masks:
   * - Credit card numbers (showing only last 4 digits)
   * - Social Security Numbers (complete masking)
   * 
   * Args:
   *     data: Data to sanitize (can be object, array, string, or other)
   *     
   * Returns:
   *     Sanitized data with same structure
   */
  // Credit card pattern - matches 13-19 digit sequences with optional separators
  const ccPattern = /\b(\d{4})[-\s]?(\d{4})[-\s]?(\d{4})[-\s]?(\d{3,6})\b/g;
  
  // SSN pattern - matches XXX-XX-XXXX format
  const ssnPattern = /\b\d{3}-\d{2}-\d{4}\b/g;
  
  function sanitizeString(text: string): string {
    /**
     * Sanitize a single string value.
     */
    if (typeof text !== 'string') {
      return text;
    }
    
    // Replace credit cards, keeping last 4 digits
    text = text.replace(ccPattern, (match, g1, g2, g3, g4) => {
      const separator = match.includes('-') ? '-' : match.includes(' ') ? ' ' : '';
      return `****${separator}****${separator}****${separator}${g4}`;
    });
    
    // Replace SSNs completely
    text = text.replace(ssnPattern, '***-**-****');
    
    return text;
  }
  
  // Handle different data types
  if (data && typeof data === 'object') {
    if (Array.isArray(data)) {
      return data.map(item => sanitizeOutput(item));
    } else {
      const result: any = {};
      for (const [key, value] of Object.entries(data)) {
        result[key] = sanitizeOutput(value);
      }
      return result;
    }
  } else if (typeof data === 'string') {
    return sanitizeString(data);
  } else {
    // For other types (number, boolean, null, undefined), return as-is
    return data;
  }
}
// ===========================================================================