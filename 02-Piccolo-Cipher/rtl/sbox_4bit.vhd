library ieee;
use ieee.std_logic_1164.all;

entity sbox_4bit is
    port (
        input  : in  std_logic_vector(3 downto 0);
        output : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of sbox_4bit is
begin

    process(input)
    begin
        case input is
            when "0000" => output <= "1110"; -- 0 -> E
            when "0001" => output <= "0100"; -- 1 -> 4
            when "0010" => output <= "1011"; -- 2 -> B
            when "0011" => output <= "0010"; -- 3 -> 2
            when "0100" => output <= "0011"; -- 4 -> 3
            when "0101" => output <= "1000"; -- 5 -> 8
            when "0110" => output <= "0000"; -- 6 -> 0
            when "0111" => output <= "1001"; -- 7 -> 9
            when "1000" => output <= "0001"; -- 8 -> 1
            when "1001" => output <= "1010"; -- 9 -> A
            when "1010" => output <= "0111"; -- A -> 7
            when "1011" => output <= "1111"; -- B -> F
            when "1100" => output <= "0110"; -- C -> 6
            when "1101" => output <= "1100"; -- D -> C
            when "1110" => output <= "0101"; -- E -> 5
            when "1111" => output <= "1101"; -- F -> D
            when others => output <= "0000";
        end case;
    end process;

end architecture;

