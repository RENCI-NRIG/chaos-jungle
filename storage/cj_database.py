#! /usr/bin/env python3

import sqlite3

sql_create_table = '''CREATE TABLE IF NOT EXISTS records (
                                id integer PRIMARY KEY,
                                filename text NOT NULL,
                                mtime real NOT NULL,
                                disk text NOT NULL,
                                targetblock integer NOT NULL,
                                targetbyte integer NOT NULL,
                                origValue integer NOT NULL,
                                afterValue integer NOT NULL
                                );'''

class Database:

    def __init__(self, logger):
        self._conn = None
        self._cursor = None
        self._logger = logger


    def connect(self, name):
        try:
            self._conn = sqlite3.connect(name)
            self._cursor = self._conn.cursor()
            return 0
        except sqlite3.Error as e:
            self._logger.debug(e)
            self._logger.info('connect {} fail'.format(name))
            return -1


    def create_table(self):
        try:
            self._cursor.execute(sql_create_table)
        except sqlite3.Error as e:
            self._logger.debug(e)


    def insert_record(self, record):
        sql = ''' INSERT INTO records(filename,mtime,disk,targetblock,targetbyte,origValue,afterValue)
                  VALUES(?,?,?,?,?,?,?) '''
        self._cursor.execute(sql, record)
        self._conn.commit()
        return self._cursor.lastrowid


    def delete_record_of_file(self, filename):
        f = (filename,)
        self._cursor.execute('DELETE FROM records WHERE filename=?', f)
        self._conn.commit()


    def get_record_of_file(self, filename):
        f = (filename,)
        self._cursor.execute('SELECT * FROM records WHERE filename=?', f)
        return self._cursor.fetchone()


    def get_all_records(self):
        self._cursor.execute('SELECT * FROM records')
        return self._cursor.fetchall()

