library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PWM_generation_avalon_interface is
    port (
        ----------------------------------------------------------------
        -- Avalon clock and reset
        ----------------------------------------------------------------
        clock  : in std_logic;
        resetn : in std_logic;

        ----------------------------------------------------------------
        -- Avalon-MM slave interface
        ----------------------------------------------------------------
        address    : in std_logic_vector(0 downto 0);
        chipselect : in std_logic;
        write      : in std_logic;
        read       : in std_logic;
        byteenable : in std_logic_vector(3 downto 0);
        writedata  : in std_logic_vector(31 downto 0);
        readdata   : out std_logic_vector(31 downto 0);

        ----------------------------------------------------------------
        -- 4-bit conduit exported outside Qsys
        ----------------------------------------------------------------
        motor_out : out std_logic_vector(3 downto 0)
    );
end entity PWM_generation_avalon_interface;

architecture rtl of PWM_generation_avalon_interface is

    --------------------------------------------------------------------
    -- Internal control registers
    --------------------------------------------------------------------
    signal ctrl_R : std_logic_vector(13 downto 0) := (others => '0');
    signal ctrl_L : std_logic_vector(13 downto 0) := (others => '0');

    constant ZERO18 : std_logic_vector(17 downto 0) := (others => '0');

    component PWM_generation is
        generic (
            F_CLK_HZ : positive := 50000000;
            F_PWM_HZ : positive := 16000
        );
        port (
            clk     : in std_logic;
            reset_n : in std_logic;

            ctrl_R : in std_logic_vector(13 downto 0);
            ctrl_L : in std_logic_vector(13 downto 0);

            motor_out : out std_logic_vector(3 downto 0)
        );
    end component;

begin

    --------------------------------------------------------------------
    -- Avalon-MM write logic
    --------------------------------------------------------------------
    process(clock, resetn)
    begin
        if resetn = '0' then

            ctrl_R <= (others => '0');
            ctrl_L <= (others => '0');

        elsif rising_edge(clock) then

            if chipselect = '1' and write = '1' then

                case address is

                    ----------------------------------------------------
                    -- Address 0: right motor register
                    -- CPU offset: BASE + 0x00
                    ----------------------------------------------------
                    when "0" =>

                        if byteenable(0) = '1' then
                            ctrl_R(7 downto 0) <= writedata(7 downto 0);
                        end if;

                        if byteenable(1) = '1' then
                            ctrl_R(13 downto 8) <= writedata(13 downto 8);
                        end if;

                    ----------------------------------------------------
                    -- Address 1: left motor register
                    -- CPU offset: BASE + 0x04
                    ----------------------------------------------------
                    when "1" =>

                        if byteenable(0) = '1' then
                            ctrl_L(7 downto 0) <= writedata(7 downto 0);
                        end if;

                        if byteenable(1) = '1' then
                            ctrl_L(13 downto 8) <= writedata(13 downto 8);
                        end if;

                    when others =>
                        null;

                end case;

            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- Avalon-MM read logic
    --------------------------------------------------------------------
    readdata <= ZERO18 & ctrl_R when address = "0" else
                ZERO18 & ctrl_L;

    --------------------------------------------------------------------
    -- PWM generator instance
    --------------------------------------------------------------------
    pwm_core : PWM_generation
        generic map (
            F_CLK_HZ => 50000000,
            F_PWM_HZ => 16000
        )
        port map (
            clk       => clock,
            reset_n   => resetn,
            ctrl_R    => ctrl_R,
            ctrl_L    => ctrl_L,
            motor_out => motor_out
        );

end architecture rtl;