type LogLevel = 'info' | 'warn' | 'error' | 'debug';

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  meta?: Record<string, unknown>;
}

function formatLog(entry: LogEntry): string {
  const metaStr = entry.meta ? ` ${JSON.stringify(entry.meta)}` : '';
  return `[${entry.timestamp}] ${entry.level.toUpperCase()}: ${entry.message}${metaStr}`;
}

function log(level: LogLevel, message: string, meta?: Record<string, unknown>): void {
  const entry: LogEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    meta,
  };
  const formatted = formatLog(entry);
  if (level === 'error' || level === 'warn') {
    console.error(formatted);
  } else {
    console.log(formatted);
  }
}

export const logger = {
  info: (message: string, meta?: Record<string, unknown>) => log('info', message, meta),
  warn: (message: string, meta?: Record<string, unknown>) => log('warn', message, meta),
  error: (message: string, meta?: Record<string, unknown>) => log('error', message, meta),
  debug: (message: string, meta?: Record<string, unknown>) => log('debug', message, meta),
};