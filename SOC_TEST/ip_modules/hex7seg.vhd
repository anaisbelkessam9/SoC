library ieee;
use ieee.std_logic_1164.all;

entity hex7seg is
    port (
        hex     : in  std_logic_vector(3 downto 0);
        display : out std_logic_vector(0 to 6)
    );
end hex7seg;

architecture Behavior of hex7seg is
begin

    process(hex)
    begin
        case hex is
            when "0000" => display <= "0000001"; -- 0
            when "0001" => display <= "1001111"; -- 1
            when "0010" => display <= "0010010"; -- 2
            when "0011" => display <= "0000110"; -- 3
            when "0100" => display <= "1001100"; -- 4
            when "0101" => display <= "0100100"; -- 5
            when "0110" => display <= "0100000"; -- 6
            when "0111" => display <= "0001111"; -- 7
            when "1000" => display <= "0000000"; -- 8
            when "1001" => display <= "0001100"; -- 9
            when "1010" => display <= "0001000"; -- A
            when "1011" => display <= "1100000"; -- b
            when "1100" => display <= "0110001"; -- C
            when "1101" => display <= "1000010"; -- d
            when "1110" => display <= "0110000"; -- E
            when "1111" => display <= "0111000"; -- F
            when others => display <= "1111111"; -- off
        end case;
    end process;

end Behavior;