import {
  normalize,
  extractQuantity,
  findCanonicalForm,
  hashNormalized,
  normalizeForHash,
} from '../services/ai/normalization';

describe('normalize', () => {
  it('lowercases content', () => {
    expect(normalize('Cappuccino')).toBe('cappuccino');
  });

  it('strips leading articles', () => {
    expect(normalize('a cappuccino')).toBe('cappuccino');
    expect(normalize('an egg')).toBe('egg');
    expect(normalize('the eggs')).toBe('eggs');
    expect(normalize('one banana')).toBe('banana');
    expect(normalize('some cheese')).toBe('cheese');
  });

  it('trims and collapses whitespace', () => {
    expect(normalize('  hello   world  ')).toBe('hello world');
  });

  it('handles unicode normalization', () => {
    // é can be represented as single char or combining sequence
    const composed = 'caf\u00E9'; // é as single char
    const decomposed = 'cafe\u0301'; // e + combining acute accent
    expect(normalize(composed)).toBe(normalize(decomposed));
  });

  it('preserves non-article words', () => {
    expect(normalize('french fries')).toBe('french fries');
    expect(normalize('flat white')).toBe('flat white');
  });
});

describe('extractQuantity', () => {
  it('parses explicit number with piece items', () => {
    const result = extractQuantity('2 eggs');
    expect(result.item).toBe('egg');
    expect(result.quantity).toBe(2);
    expect(result.unit).toBe('piece');
  });

  it('parses grams', () => {
    const result = extractQuantity('200g chicken breast');
    expect(result.item).toBe('chicken breast');
    expect(result.quantity).toBe(200);
    expect(result.unit).toBe('g');
  });

  it('parses grams with space: "200 g chicken"', () => {
    const result = extractQuantity('200 g chicken');
    expect(result.item).toBe('chicken');
    expect(result.quantity).toBe(200);
    expect(result.unit).toBe('g');
  });

  it('parses word: half', () => {
    const result = extractQuantity('half croissant');
    expect(result.item).toBe('croissant');
    expect(result.quantity).toBe(0.5);
    expect(result.unit).toBe('piece');
  });

  it('parses word: quarter', () => {
    const result = extractQuantity('quarter pizza');
    expect(result.item).toBe('pizza');
    expect(result.quantity).toBe(0.25);
    expect(result.unit).toBe('piece');
  });

  it('parses "a" as 1', () => {
    const result = extractQuantity('a cappuccino');
    expect(result.item).toBe('cappuccino');
    expect(result.quantity).toBe(1);
  });

  it('parses word numbers: two, three', () => {
    expect(extractQuantity('two eggs').quantity).toBe(2);
    expect(extractQuantity('three bananas').quantity).toBe(3);
  });

  it('parses units: slices, cups, servings', () => {
    expect(extractQuantity('3 slices bread').unit).toBe('slice');
    expect(extractQuantity('3 slices bread').quantity).toBe(3);
    expect(extractQuantity('1 cup milk').unit).toBe('cup');
    expect(extractQuantity('2 servings rice').unit).toBe('serving');
  });

  it('handles "X of Y" pattern', () => {
    const result = extractQuantity('large serving of french fries');
    expect(result.item).toBe('french fries');
    expect(result.quantity).toBe(1);
    expect(result.unit).toBe('serving');
  });

  it('defaults to 1 piece when no quantity given', () => {
    const result = extractQuantity('cappuccino');
    expect(result.item).toBe('cappuccino');
    expect(result.quantity).toBe(1);
    expect(result.unit).toBe('piece');
  });

  it('parses kg', () => {
    const result = extractQuantity('1.5kg chicken');
    expect(result.item).toBe('chicken');
    expect(result.quantity).toBe(1.5);
    expect(result.unit).toBe('kg');
  });

  it('parses ml', () => {
    const result = extractQuantity('250ml milk');
    expect(result.item).toBe('milk');
    expect(result.quantity).toBe(250);
    expect(result.unit).toBe('ml');
  });
});

describe('findCanonicalForm', () => {
  it('resolves English to canonical', () => {
    expect(findCanonicalForm('cappuccino')).toBe('cappuccino');
  });

  it('resolves Russian variants to canonical', () => {
    expect(findCanonicalForm('капучино')).toBe('cappuccino');
    expect(findCanonicalForm('каппучино')).toBe('cappuccino');
  });

  it('resolves case-insensitively', () => {
    expect(findCanonicalForm('CAPPuccino')).toBe('cappuccino');
    expect(findCanonicalForm('КАПУЧИНО')).toBe('cappuccino');
  });

  it('resolves egg variants', () => {
    expect(findCanonicalForm('яйцо')).toBe('egg');
    expect(findCanonicalForm('яйца')).toBe('egg');
  });

  it('returns null for unknown items', () => {
    expect(findCanonicalForm('sushi roll')).toBeNull();
  });

  it('resolves multi-word items', () => {
    expect(findCanonicalForm('flat white')).toBe('flat white');
    expect(findCanonicalForm('флэт уайт')).toBe('flat white');
    expect(findCanonicalForm('french fries')).toBe('french fries');
    expect(findCanonicalForm('картошка фри')).toBe('french fries');
  });
});

describe('hashNormalized', () => {
  it('produces consistent hashes for same content', () => {
    const h1 = hashNormalized('cappuccino');
    const h2 = hashNormalized('cappuccino');
    expect(h1).toBe(h2);
  });

  it('produces different hashes for different content', () => {
    const h1 = hashNormalized('cappuccino');
    const h2 = hashNormalized('flat white');
    expect(h1).not.toBe(h2);
  });
});

describe('multilingual hash equivalence', () => {
  it('капучино and cappuccino normalize to the same hash', () => {
    const h1 = hashNormalized(normalizeForHash('капучино'));
    const h2 = hashNormalized(normalizeForHash('cappuccino'));
    expect(h1).toBe(h2);
  });

  it('different Russian/English egg forms resolve to same hash', () => {
    const h1 = hashNormalized(normalizeForHash('яйцо'));
    const h2 = hashNormalized(normalizeForHash('egg'));
    const h3 = hashNormalized(normalizeForHash('яйца'));
    expect(h1).toBe(h2);
    expect(h2).toBe(h3);
  });

  it('"a cappuccino" and "cappuccino" have the same hash', () => {
    const h1 = hashNormalized(normalizeForHash('a cappuccino'));
    const h2 = hashNormalized(normalizeForHash('cappuccino'));
    expect(h1).toBe(h2);
  });
});
