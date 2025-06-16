/**
 * SPL risk rules configuration for query validation.
 * 
 * This file contains all SPL risk validation rules in a single location
 * for easy adjustment and maintenance. Each rule can be:
 * - A regex pattern with a fixed risk score
 * - A function with a single score or tuple of scores for different outcomes
 * 
 * Modify scores and messages here to adjust SPL validation behavior.
 */

import {
  checkCollectParams,
  checkOutputlookupParams,
  checkIndexUsage,
  checkTimeRange,
  checkExpensiveCommands,
  checkAppendOperations,
  checkSubsearchLimits,
  RiskScore,
  ValidationContext,
  ValidationResult
} from './guardrails';

type RuleFunction = (query: string, context: ValidationContext, baseRisk: RiskScore) => number | ValidationResult;
type RulePattern = string;
type Rule = [RulePattern | RuleFunction, RiskScore, string];

// ===========================================================================
// Risk rules definition: (pattern_or_function, score, message_with_suggestion)
export const SPL_RISK_RULES: Rule[] = [
  // Simple regex rules
  [String.raw`\|\s*delete\b`, 80,
   "Uses 'delete' command (+{score}). This permanently removes data. Ensure you have backups and proper authorization before using delete."],
  
  [String.raw`\|\s*(script|external)\b`, 40,
   "Uses external script execution (+{score}). Ensure scripts are trusted and review security implications."],
  
  // Function-based rules
  [checkCollectParams, 25,
   "Uses 'collect' with risky parameters (+{score}). Consider using addtime=true and avoid override=true for safer data collection."],
  
  [checkOutputlookupParams, 20,
   "Uses 'outputlookup' with override=true (+{score}). This will overwrite existing lookup. Consider append=true or create a new lookup file."],
  
  [checkIndexUsage, [0, 20, 35],  // [no_risk, no_index_with_constraints, index_star_unconstrained]
   "Index usage issue detected (+{score}). Specify exact indexes or add source/sourcetype constraints for better performance."],
  
  [checkTimeRange, [0, 20, 50],  // [no_risk, exceeds_safe_range, all_time/no_time]
   "Time range issue detected (+{score}). Add time constraints like earliest=-24h latest=now to limit search scope."],
  
  [checkExpensiveCommands, 20,  // Base score per command
   "Uses expensive command(s) (+{score}). Consider using stats commands instead of transaction/map/join for better performance."],
  
  [checkAppendOperations, 15,
   "Uses append operations (+{score}). These can be memory intensive. Consider using OR conditions or union command."],
  
  [checkSubsearchLimits, 20,
   "Subsearch without explicit limits (+{score}). Add maxout= or maxresults= to subsearches to prevent timeout issues."],
];
// ===========================================================================