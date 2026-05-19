library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PWM_generation is
    generic (
        F_CLK_HZ : positive := 50000000;
        F_PWM_HZ : positive := 16000
    );
    port (
        clk     : in std_logic;
        reset_n : in std_logic;

        ctrl_R : in std_logic_vector(13 downto 0);
        ctrl_L : in std_logic_vector(13 downto 0);

        -- 4-bit conduit output
        -- motor_out(3) = dc_motor_p_R
        -- motor_out(2) = dc_motor_n_R
        -- motor_out(1) = dc_motor_p_L
        -- motor_out(0) = dc_motor_n_L
        motor_out : out std_logic_vector(3 downto 0)
    );
end entity PWM_generation;

architecture rtl of PWM_generation is

    constant PWM_PERIOD : natural := F_CLK_HZ / F_PWM_HZ;
    -- 50 MHz / 16 kHz = 3125 clock cycles

    signal tick  : natural range 0 to PWM_PERIOD - 1 := 0;
    signal pwm_R : std_logic := '0';
    signal pwm_L : std_logic := '0';

    function clamp_duty(duty : unsigned(11 downto 0)) return natural is
        variable d : natural;
    begin
        d := to_integer(duty);

        if d >= PWM_PERIOD then
            return PWM_PERIOD;
        else
            return d;
        end if;
    end function;

begin

    process(clk, reset_n)
        variable duty_R : natural;
        variable duty_L : natural;
    begin
        if reset_n = '0' then
            tick  <= 0;
            pwm_R <= '0';
            pwm_L <= '0';

        elsif rising_edge(clk) then

            duty_R := clamp_duty(unsigned(ctrl_R(11 downto 0)));
            duty_L := clamp_duty(unsigned(ctrl_L(11 downto 0)));

            if tick = PWM_PERIOD - 1 then
                tick <= 0;
            else
                tick <= tick + 1;
            end if;

            if tick < duty_R then
                pwm_R <= '1';
            else
                pwm_R <= '0';
            end if;

            if tick < duty_L then
                pwm_L <= '1';
            else
                pwm_L <= '0';
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- Motor output mapping
    --------------------------------------------------------------------
    -- Right motor
    motor_out(3) <= pwm_R when ctrl_R(13) = '1' and ctrl_R(12) = '0' else '0';
    motor_out(2) <= pwm_R when ctrl_R(13) = '1' and ctrl_R(12) = '1' else '0';

    -- Left motor
    motor_out(1) <= pwm_L when ctrl_L(13) = '1' and ctrl_L(12) = '0' else '0';
    motor_out(0) <= pwm_L when ctrl_L(13) = '1' and ctrl_L(12) = '1' else '0';

end architecture rtl;