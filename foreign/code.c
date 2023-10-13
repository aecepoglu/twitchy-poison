#include <unistd.h>
#include <termios.h>
#include <stdlib.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>

#define SOCK_PATH "/tmp/goldfish.sock"

struct termios initial;

const int RESP_LEN = strlen("ok.\r\n");
const int ERR_RECONNECT = -2;
const int ERR_UNDEF = -1;
const int ERR_BASIC = 0;

pid_t child_pid;

void restore(void) {
	tcsetattr(1, TCSANOW, &initial);
};
void die(int i) {
	if (child_pid != 0) {
		kill(child_pid, SIGKILL);
	}
	exit(1);
}

void terminit(void) {
	struct termios t;
	tcgetattr(1, &t);
	initial = t;
	atexit(restore);
	signal(SIGTERM, die);
	signal(SIGINT, die);
	t.c_lflag &= (~ECHO & ~ICANON);
	tcsetattr(1, TCSANOW, &t);
}

	/*
*/



int send_msg(int sd, const char *msg, char *resp_buf) {
	int rc = send(sd, msg, strlen(msg), 0);
	if (rc < 0) { perror("send() failed"); return ERR_BASIC; }
	rc = recv(sd, &resp_buf, RESP_LEN, 0);
	if (rc < 0) { perror("recv() failed"); return ERR_BASIC; }
	if (rc == 0) { printf("The server closed the connection\n"); return ERR_RECONNECT; }
	return rc;
}

int connect_socket(const char *socket_path) {
	struct sockaddr_un serveraddr;

	int sd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (sd < 0) { perror("socket() failed"); return -1; }

	memset(&serveraddr, 0, sizeof(serveraddr));
	serveraddr.sun_family = AF_UNIX;
	strcpy(serveraddr.sun_path, socket_path);

	int rc = connect(sd, (struct sockaddr *)&serveraddr, SUN_LEN(&serveraddr));
	if (rc < 0) { perror("connect() failed"); return -1; }

	return sd;
}

void start_kbd_listener() {
	char buffer[256];
	char msgbuf[32];
	int sd = -1;
	int rc = 99;

	terminit();
	while (sd < 0) {
		for (int retry = 0; sd < 0 && retry < 10; retry ++) {
			printf("attempt #%d to connect\n", retry);
			sleep(1);
			sd = connect_socket(SOCK_PATH);
		}
		if (sd <= 0) { printf("sd isn't what I expected\n"); return; }

		for (char key; sd > 0;) {
			read(1, &key, 1);
			if ((key >= 'a' && key <= 'z') || (key >= '0' && key <= '9') || key == 27) {
				switch (key) {
					case 27: sprintf(msgbuf, "key %s\r\n", "escape"); break;
					case 't':  sprintf(msgbuf, "key %s\r\n", "down"); break;
					case 'n':  sprintf(msgbuf, "key %s\r\n", "up"); break;
					default:   sprintf(msgbuf, "key %c\r\n", key); break;
				}
				rc = send_msg(sd, msgbuf, buffer);
				if (rc == ERR_RECONNECT) {
					printf("need to reconnect.\n");
					sd = -1;
					continue;
				}
			}
		}
	}

	if (sd != -1) { close(sd); }
}

int main(int argc, char *argv[]) {
	if (argc != 2) { printf("Usage: %s /path/to/rel/twitchy_poison", argv[0]); return 1; }

	int fd[2];
	child_pid = fork();
	if (child_pid == 0) {
		fclose(stdin);
		const char *bin = argv[1];
		execl(bin, bin, "start");
	} else {
		start_kbd_listener();
		printf("awaiting child\n");
		wait(0);
		printf("child fin.");
	}

	return 0;
}
