#include <stdio.h>
#include "system.h"
#include "io.h"
#include "unistd.h"

/* Sensor registers */
#define REG_READY_VECT  0x00
#define REG_NIVEAU      0x01

/* PWM registers */
#define PWM_RIGHT        0x00
#define PWM_LEFT         0x04

/* PWM bits */
#define GO_BIT           13
#define DIR_BIT          12

/* Motor direction */
#define RIGHT_FORWARD    0
#define LEFT_FORWARD     1

/* Tuning */
#define THRESHOLD        0x6C

/* Speeds = DUTY only, not full command */
#define SPEED_SLOW       0x0800   /* min to move: full command right = 0x28C0 */
#define SPEED_NORMAL     0x08A0
#define SPEED_FAST       0x0A00
#define SPEED_MAX        0x0A00   /* 3125 decimal */


unsigned int pwm_cmd(unsigned int go, unsigned int dir, unsigned int duty)
{
    if (duty > 3125)
        duty = 3125;

    return ((go & 1) << GO_BIT) |
           ((dir & 1) << DIR_BIT) |
           (duty & 0x0FFF);
}


void motors_stop(void)
{
    IOWR_32DIRECT(PWM_GENERATION_AVALON_INTERFACE_0_BASE, PWM_RIGHT, 0x00000000);
    IOWR_32DIRECT(PWM_GENERATION_AVALON_INTERFACE_0_BASE, PWM_LEFT,  0x00000000);
}


void motors_forward(unsigned int right_speed, unsigned int left_speed)
{
    IOWR_32DIRECT(
        PWM_GENERATION_AVALON_INTERFACE_0_BASE,
        PWM_RIGHT,
        pwm_cmd(1, RIGHT_FORWARD, right_speed)
    );

    IOWR_32DIRECT(
        PWM_GENERATION_AVALON_INTERFACE_0_BASE,
        PWM_LEFT,
        pwm_cmd(1, LEFT_FORWARD, left_speed)
    );
}


void print_vect(unsigned char vect)
{
    int i;

    for (i = 6; i >= 0; i--)
    {
        if (vect & (1 << i))
            printf("1");
        else
            printf("0");
    }
}


int main(void)
{
    unsigned char ready_vect;
    unsigned char ready;
    unsigned char vect;

    printf("CUTECAR simple line follower\n");

    /* Set threshold = 0x6C */
    IOWR_8DIRECT(CAPTEURS_SOL_SEUIL_AVALON_0_BASE, REG_NIVEAU, THRESHOLD);

    usleep(100000);

    while (1)
    {
        ready_vect = IORD_8DIRECT(CAPTEURS_SOL_SEUIL_AVALON_0_BASE, REG_READY_VECT);

        ready = (ready_vect & 0x80) >> 7;
        vect  = ready_vect & 0x7F;

        printf("vect = ");
        print_vect(vect);
        printf("  ready=%d\n", ready);

        if (ready == 0)
        {
            motors_stop();
        }
        else if (vect == 0x00)
        {
            motors_stop();
        }
        else if (vect & 0x08)
        {
            /* Center sensor: go straight */
            motors_forward(SPEED_NORMAL, SPEED_NORMAL);
        }
        else if (vect & 0x07)
        {
            /* Line on left side: turn left */
            motors_forward(SPEED_FAST, SPEED_SLOW);
        }
        else if (vect & 0x70)
        {
            /* Line on right side: turn right */
            motors_forward(SPEED_FAST, SPEED_SLOW);
        }
        else
        {
            motors_stop();
        }

        usleep(50000);
    }

    return 0;
}