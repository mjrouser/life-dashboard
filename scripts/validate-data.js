#!/usr/bin/env node
// validate-data.js — validates dashboard-data.json schema and referential integrity
// Usage: node scripts/validate-data.js [path/to/dashboard-data.json]
// Install pre-commit hook:
//   printf '#!/bin/sh\nnode "$(git rev-parse --show-toplevel)/scripts/validate-data.js"\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

const fs = require('fs');
const path = require('path');

const DATA_PATH = process.argv[2] || path.join(__dirname, '..', 'dashboard-data.json');

const VALID_STATUSES = new Set([
  'active-deadline', 'active-in-progress', 'live-has-tail',
  'ready', 'parked', 'queued', 'shipped'
]);

const EA_FIELDS = ['blocker_type', 'agent_can_do', 'agent_can_prep', 'agent_needs', 'cooldown_until'];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const VALID_ENERGY = new Set(['low', 'medium', 'high']);
const VALID_LOG_TYPES = new Set(['active', 'shipped', 'new_idea']);

function checkStatuses(data) {
  const errors = [];
  for (const chat of data.chats) {
    if (!VALID_STATUSES.has(chat.status)) {
      errors.push(`[${chat.id}] status "${chat.status}" is not a valid value`);
    }
  }
  return errors;
}

function checkCategoryRefs(data) {
  const errors = [];
  const categoryIds = new Set(data.categories.map(c => c.id));
  for (const chat of data.chats) {
    if (!categoryIds.has(chat.category_id)) {
      errors.push(`[${chat.id}] category_id "${chat.category_id}" does not reference a known category`);
    }
  }
  return errors;
}

function checkGroupRefs(data) {
  const errors = [];
  const groupIds = new Set((data.groups || []).map(g => g.id));
  for (const chat of data.chats) {
    if (chat.group_id && !groupIds.has(chat.group_id)) {
      errors.push(`[${chat.id}] group_id "${chat.group_id}" does not reference a known group`);
    }
  }
  return errors;
}

function checkTodayRefs(data) {
  const errors = [];
  const chatIds = new Set(data.chats.map(c => c.id));
  for (const entry of (data.today || [])) {
    if (!chatIds.has(entry.chat_id)) {
      errors.push(`[today] chat_id "${entry.chat_id}" does not reference a known chat`);
    }
  }
  return errors;
}

function checkEAFields(data) {
  const errors = [];
  for (const chat of data.chats) {
    for (const field of EA_FIELDS) {
      if (!(field in chat)) {
        errors.push(`[${chat.id}] missing required EA field: ${field}`);
      }
    }
  }
  return errors;
}

function checkDateFormats(data) {
  const errors = [];
  for (const chat of data.chats) {
    if (chat.updated && !DATE_RE.test(chat.updated)) {
      errors.push(`[${chat.id}] updated "${chat.updated}" is not a valid YYYY-MM-DD date`);
    }
    if (chat.cooldown_until && !DATE_RE.test(chat.cooldown_until)) {
      errors.push(`[${chat.id}] cooldown_until "${chat.cooldown_until}" is not a valid YYYY-MM-DD date`);
    }
  }
  return errors;
}

function checkEnergyValues(data) {
  const errors = [];
  for (const chat of data.chats) {
    if (chat.energy != null && !VALID_ENERGY.has(chat.energy)) {
      errors.push(`[${chat.id}] energy "${chat.energy}" is not a valid value`);
    }
  }
  return errors;
}

function checkActivityLogTypes(data) {
  const errors = [];
  for (const entry of (data.activity_log || [])) {
    for (const type of (entry.types || [])) {
      if (!VALID_LOG_TYPES.has(type)) {
        errors.push(`[activity_log:${entry.date}] type "${type}" is not a valid value`);
      }
    }
  }
  return errors;
}

function main() {
  let data;
  try {
    data = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
  } catch (e) {
    console.error(`✗ Could not read or parse ${DATA_PATH}: ${e.message}`);
    process.exit(1);
  }

  const errors = [
    ...checkStatuses(data),
    ...checkCategoryRefs(data),
    ...checkGroupRefs(data),
    ...checkTodayRefs(data),
    ...checkEAFields(data),
    ...checkDateFormats(data),
    ...checkEnergyValues(data),
    ...checkActivityLogTypes(data),
  ];

  if (errors.length === 0) {
    console.log('✓ dashboard-data.json is valid');
    process.exit(0);
  } else {
    console.error(`✗ dashboard-data.json has ${errors.length} error(s):\n`);
    for (const err of errors) {
      console.error(`  ${err}`);
    }
    process.exit(1);
  }
}

main();
