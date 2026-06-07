import crypto from 'crypto';
import synonymsMap from './synonyms.json';

// Build a reverse lookup map: variant (lowercased) → canonical form
const variantToCanonical = new Map<string, string>();
for (const [canonical, variants] of Object.entries(synonymsMap)) {
  for (const variant of variants) {
    variantToCanonical.set(variant.toLowerCase(), canonical.toLowerCase());
  }
}

// Articles to strip from content (multilingual)
const ARTICLES = new Set([
  'a', 'an', 'the', 'one', 'some',
  'один', 'одна', 'одно', 'некоторые',
  'un', 'une', 'des', 'le', 'la', 'les',
  'der', 'die', 'das', 'ein', 'eine',
]);

// Word-to-number map for small quantities expressed as words
const WORD_NUMBERS: Record<string, number> = {
  'half': 0.5,
  'quarter': 0.25,
  'third': 1 / 3,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'a': 1,
  'an': 1,
};

// Recognized units and their canonical forms
const UNIT_MAP: Record<string, string> = {
  'g': 'g',
  'gram': 'g',
  'grams': 'g',
  'кг': 'kg',
  'kg': 'kg',
  'kilogram': 'kg',
  'kilograms': 'kg',
  'ml': 'ml',
  'milliliter': 'ml',
  'milliliters': 'ml',
  'мл': 'ml',
  'l': 'l',
  'liter': 'l',
  'liters': 'l',
  'л': 'l',
  'oz': 'oz',
  'ounce': 'oz',
  'ounces': 'oz',
  'lb': 'lb',
  'lbs': 'lb',
  'pound': 'lb',
  'pounds': 'lb',
  'cup': 'cup',
  'cups': 'cup',
  'чашка': 'cup',
  'чашки': 'cup',
  'slice': 'slice',
  'slices': 'slice',
  'ломтик': 'slice',
  'ломтика': 'slice',
  'piece': 'piece',
  'pieces': 'piece',
  'шт': 'piece',
  'штука': 'piece',
  'штуки': 'piece',
  'serving': 'serving',
  'servings': 'serving',
  'порция': 'serving',
  'порции': 'serving',
};

export interface ExtractedQuantity {
  item: string;
  quantity: number;
  unit: string;
}

/**
 * Split a free-form food block into individual item segments for per-item cache lookup.
 *
 * Splits on: "and" (word-bounded), "+", "&", "," and newlines.
 * Does NOT split on "with" — "coffee with milk" is one item, not two.
 * Returns [content] unchanged when splitting would yield only one piece.
 *
 * Examples:
 *   "cappuccino and banana"       → ["cappuccino", "banana"]
 *   "chicken, rice and beans"     → ["chicken", "rice", "beans"]
 *   "flat white + croissant"      → ["flat white", "croissant"]
 *   "coffee with milk"            → ["coffee with milk"]
 *   "2.5 eggs"                    → ["2.5 eggs"]
 */
export function splitIntoSegments(content: string): string[] {
  // Word-bounded "and", plus "+", "&", "," separators and newlines.
  // The \b ensures we don't split on "sandwich" or "bland".
  const SEPARATOR_RE = /\band\b|\s*[+&,]\s*|\n+/gi;

  const pieces = content.split(SEPARATOR_RE);
  const segments = pieces.map(s => s.trim()).filter(s => s.length > 0);

  if (segments.length <= 1) return [content.trim() || content];

  return segments;
}

/**
 * Normalize a food content string:
 * - Lowercase
 * - Unicode normalization (NFC)
 * - Strip leading articles
 * - Trim and collapse whitespace
 */
export function normalize(content: string): string {
  let normalized = content
    .normalize('NFC')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');

  // Strip leading articles: "a cappuccino" → "cappuccino", "the eggs" → "eggs"
  const words = normalized.split(' ');
  while (words.length > 0 && ARTICLES.has(words[0])) {
    words.shift();
  }
  normalized = words.join(' ');

  return normalized;
}

/**
 * Extract quantity, unit, and item name from a food description.
 * Handles: "2 eggs", "200g chicken breast", "half croissant", "a cappuccino",
 * "large serving of french fries", etc.
 */
export function extractQuantity(content: string): ExtractedQuantity {
  const normalized = normalize(content);
  const words = normalized.split(' ');

  // Check for "X of Y" pattern like "serving of french fries", "cup of milk"
  const ofIndex = words.indexOf('of');

  if (ofIndex > 0) {
    const afterOf = words.slice(ofIndex + 1).join(' ');
    const beforeOf = words.slice(0, ofIndex);

    // Try to extract quantity from before "of"
    const qtyFromBefore = parseLeadingQuantity(beforeOf);
    if (qtyFromBefore) {
      return {
        item: resolveCanonical(afterOf),
        quantity: qtyFromBefore.quantity,
        unit: qtyFromBefore.unit,
      };
    }

    // Search for a unit word within before-of words (e.g. "large serving of ...")
    for (let i = beforeOf.length - 1; i >= 0; i--) {
      if (UNIT_MAP[beforeOf[i]]) {
        const unit = UNIT_MAP[beforeOf[i]];
        // Check if there's a number before this unit within beforeOf
        let qty = 1;
        if (i > 0) {
          const prevWord = beforeOf[i - 1];
          const numMatch = prevWord.match(/^(\d+(?:\.\d+)?)$/);
          if (numMatch) {
            qty = parseFloat(numMatch[1]);
          } else if (WORD_NUMBERS[prevWord] !== undefined) {
            qty = WORD_NUMBERS[prevWord];
          }
        }
        return {
          item: resolveCanonical(afterOf),
          quantity: qty,
          unit,
        };
      }
    }

    // No quantity or unit found before "of", treat as 1 piece
    return {
      item: resolveCanonical(afterOf),
      quantity: 1,
      unit: 'piece',
    };
  }

  // Try leading number: "2 eggs", "200g chicken breast"
  const leadingQty = parseLeadingQuantity(words);
  if (leadingQty) {
    const remaining = words.slice(leadingQty.consumed).join(' ');
    return {
      item: resolveCanonical(remaining),
      quantity: leadingQty.quantity,
      unit: leadingQty.unit,
    };
  }

  // Try trailing unit pattern: "chicken 200g"
  if (words.length >= 2) {
    const lastWord = words[words.length - 1];
    const trailingMatch = lastWord.match(/^(\d+(?:\.\d+)?)(g|kg|ml|l|oz|lb|мл|кг|л)$/)
      || lastWord.match(/^(\d+(?:\.\d+)?)\s*(g|kg|ml|l|oz|lb|мл|кг|л)$/);
    if (trailingMatch) {
      const qty = parseFloat(trailingMatch[1]);
      const unit = UNIT_MAP[trailingMatch[2]] || trailingMatch[2];
      const item = words.slice(0, -1).join(' ');
      return {
        item: resolveCanonical(item),
        quantity: qty,
        unit,
      };
    }
  }

  // No quantity detected — default to 1 piece
  return {
    item: resolveCanonical(normalized),
    quantity: 1,
    unit: 'piece',
  };
}

/**
 * Parse a leading quantity from an array of words.
 * Returns quantity, unit, and number of words consumed, or null if not parseable.
 */
function parseLeadingQuantity(words: string[]): { quantity: number; unit: string; consumed: number } | null {
  if (words.length === 0) return null;

  const first = words[0];

  // Check for number-unit combined: "200g", "300ml"
  const combinedMatch = first.match(/^(\d+(?:\.\d+)?)(g|kg|ml|l|oz|lb|мл|кг|л)$/);
  if (combinedMatch) {
    const qty = parseFloat(combinedMatch[1]);
    const unit = UNIT_MAP[combinedMatch[2]] || combinedMatch[2];
    return { quantity: qty, unit, consumed: 1 };
  }

  // Check for standalone number: "2", "2.5"
  const numMatch = first.match(/^(\d+(?:\.\d+)?)\s*$/);
  if (numMatch) {
    const qty = parseFloat(numMatch[1]);
    // Check if next word is a unit
    if (words.length > 1 && UNIT_MAP[words[1]]) {
      return { quantity: qty, unit: UNIT_MAP[words[1]], consumed: 2 };
    }
    return { quantity: qty, unit: 'piece', consumed: 1 };
  }

  // Check for number with attached unit and space: "200 g"
  const numMatch2 = first.match(/^(\d+(?:\.\d+)?)$/);
  if (numMatch2) {
    const qty = parseFloat(numMatch2[1]);
    if (words.length > 1 && UNIT_MAP[words[1]]) {
      return { quantity: qty, unit: UNIT_MAP[words[1]], consumed: 2 };
    }
    return { quantity: qty, unit: 'piece', consumed: 1 };
  }

  // Check for word numbers: "half", "two", etc.
  if (WORD_NUMBERS[first] !== undefined) {
    const qty = WORD_NUMBERS[first];
    // Check if next word is a unit: "half cup", "two slices"
    if (words.length > 1 && UNIT_MAP[words[1]]) {
      return { quantity: qty, unit: UNIT_MAP[words[1]], consumed: 2 };
    }
    return { quantity: qty, unit: 'piece', consumed: 1 };
  }

  return null;
}

/**
 * Attempt basic English singularization for lookup fallback.
 */
function trySingularize(word: string): string | null {
  if (word.length <= 2) return null;
  // -ies → -y (e.g. "cherries" → "cherry")
  if (word.endsWith('ies') && word.length > 4) {
    return word.slice(0, -3) + 'y';
  }
  // -es → remove (e.g. "slices" → "slice", "potatoes" → "potato")
  if (word.endsWith('es') && word.length > 3) {
    return word.slice(0, -2);
  }
  // -s → remove (e.g. "eggs" → "egg", "bananas" → "banana")
  if (word.endsWith('s') && !word.endsWith('ss')) {
    return word.slice(0, -1);
  }
  return null;
}

/**
 * Look up a food item in the multilingual synonyms map.
 * Returns the canonical form if found, otherwise returns null.
 * Also tries basic English singularization as a fallback.
 */
export function findCanonicalForm(normalizedContent: string): string | null {
  const lookup = normalizedContent.toLowerCase().trim();
  // Direct synonym match
  if (variantToCanonical.has(lookup)) {
    return variantToCanonical.get(lookup)!;
  }
  // Check if it's already a canonical form
  if (synonymsMap && (synonymsMap as Record<string, string[]>)[lookup]) {
    return lookup;
  }
  // Try singularized form for multi-word items or single words
  const singular = trySingularize(lookup);
  if (singular) {
    if (variantToCanonical.has(singular)) {
      return variantToCanonical.get(singular)!;
    }
    if ((synonymsMap as Record<string, string[]>)[singular]) {
      return singular;
    }
  }
  // Try singularizing just the last word of a multi-word item
  const words = lookup.split(' ');
  if (words.length > 1) {
    const lastWord = words[words.length - 1];
    const singularLast = trySingularize(lastWord);
    if (singularLast) {
      const singularPhrase = [...words.slice(0, -1), singularLast].join(' ');
      if (variantToCanonical.has(singularPhrase)) {
        return variantToCanonical.get(singularPhrase)!;
      }
      if ((synonymsMap as Record<string, string[]>)[singularPhrase]) {
        return singularPhrase;
      }
    }
  }
  return null;
}

/**
 * Resolve the item name to canonical form if available,
 * otherwise return the original normalized name.
 */
function resolveCanonical(item: string): string {
  const canonical = findCanonicalForm(item);
  return canonical || item;
}

/**
 * Compute a SHA256 hash of the normalized content for fast lookups.
 */
export function hashNormalized(content: string): string {
  return crypto.createHash('sha256').update(content).digest('hex');
}

/**
 * Get the full normalization + canonical resolution for a food item.
 * Used to produce the normalized_hash for cache storage.
 */
export function normalizeForHash(content: string): string {
  const normalized = normalize(content);
  const qty = extractQuantity(content);
  // Hash is based on the canonical item name only (no quantity)
  const canonical = findCanonicalForm(qty.item);
  return canonical || normalized;
}
