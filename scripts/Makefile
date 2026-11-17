CC = gcc
CFLAGS = -Wall -Wextra -pedantic
LDFLAGS = -lcrypto

TARGET = md5-fix
SRCS = md5-fix.c

all: $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) $(SRCS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(TARGET)
