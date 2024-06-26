
import mysql.connector
from mysql.connector import Error
from dotenv import load_dotenv
from datetime import datetime
import os

# Load environment variables
load_dotenv()

# Connection settings
HOST = os.getenv('host')
USER = os.getenv('user')
PASSWORD = os.getenv('password')
DATABASE = os.getenv('database')


def create_connection():
    try:
        connection = mysql.connector.connect(
            host=HOST,
            user=USER,
            password=PASSWORD,
            database=DATABASE
        )
        if connection.is_connected():
            print("Connected to MySQL database")
            return connection
    except Error as e:
        print(f"Error: {e}")
    return None


def read_uncommited_demo():
    """
    Shows how READ COMMITTED isolation level works.
    Shows Non-repeatable Read.
    :return: void
    """
    connection1 = create_connection()
    connection2 = create_connection()

    if not connection1 or not connection2:
        print("Failed to create database connections")
        return

    try:
        cursor1 = connection1.cursor()
        cursor2 = connection2.cursor()

        # Transaction 1: Read Uncommitted
        print(f"Transaction 1 started: {datetime.now()}")
        connection1.start_transaction(isolation_level='READ COMMITTED')
        cursor1.execute("SELECT balance FROM accounts WHERE name = 'Alice'")
        balance_read = cursor1.fetchone()[0]

        print(f"Alice's balance = {balance_read}")

        # Transaction 2: Read committed
        print(f"Transaction 2 started: {datetime.now()}")
        connection2.start_transaction(isolation_level='READ COMMITTED')
        cursor2.execute("UPDATE accounts SET balance = 9999 WHERE name = 'Alice'")

        cursor1.execute("SELECT balance FROM accounts WHERE name = 'Alice'")
        balance_read = cursor1.fetchone()[0]

        print(f" (READ COMMITTED): Alice's balance = {balance_read}")

        print(f"Transaction 2 commit(): {datetime.now()}")
        connection2.commit()



        # Transaction 1 - Check balance
        cursor1.execute("SELECT balance FROM accounts WHERE name = 'Alice'")
        balance_non_repeatable_read = cursor1.fetchone()[0]

        print(f"Non-Repeatable read (READ COMMITTED): Alice's balance = {balance_non_repeatable_read}")

    except Error as e:
        print(f"Error: {e}")
    finally:
        if connection1:
            if cursor1:
                cursor1.close()
            if connection1.is_connected():
                connection1.close()
        if connection2:
            if cursor2:
                cursor2.close()
            if connection2.is_connected():
                connection2.close()


if __name__ == "__main__":
    read_uncommited_demo()